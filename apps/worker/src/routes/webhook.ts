import { Hono } from 'hono';
import { verifySignature, LineClient } from '@line-crm/line-sdk';
import type { WebhookRequestBody, WebhookEvent, TextEventMessage } from '@line-crm/line-sdk';
import {
  upsertFriend,
  updateFriendFollowStatus,
  getFriendByLineUserId,
  getScenarios,
  enrollFriendInScenario,
  getScenarioSteps,
  advanceFriendScenario,
  completeFriendScenario,
  upsertChatOnMessage,
  getLineAccounts,
  jstNow,
} from '@line-crm/db';
import { fireEvent } from '../services/event-bus.js';
import { buildMessage, expandVariables } from '../services/step-delivery.js';
import { handleDiagnosisMessage } from '../services/diagnosis-bot.js';
import { detectEscalation, buildAcknowledgeMessage, getEscalationBehavior, ESCALATION_LABELS } from '../services/escalation-detector.js';
import { notifyEscalation } from '../services/escalation-notify.js';
import type { Env } from '../index.js';

const webhook = new Hono<Env>();

webhook.post('/webhook', async (c) => {
  const rawBody = await c.req.text();
  const signature = c.req.header('X-Line-Signature') ?? '';
  const db = c.env.DB;

  let body: WebhookRequestBody;
  try {
    body = JSON.parse(rawBody) as WebhookRequestBody;
  } catch {
    console.error('Failed to parse webhook body');
    return c.json({ status: 'ok' }, 200);
  }

  // Multi-account: resolve credentials from DB by destination (channel user ID)
  // or fall back to environment variables (default account)
  let channelSecret = c.env.LINE_CHANNEL_SECRET;
  let channelAccessToken = c.env.LINE_CHANNEL_ACCESS_TOKEN;
  let matchedAccountId: string | null = null;

  if ((body as { destination?: string }).destination) {
    const accounts = await getLineAccounts(db);
    for (const account of accounts) {
      if (!account.is_active) continue;
      const isValid = await verifySignature(account.channel_secret, rawBody, signature);
      if (isValid) {
        channelSecret = account.channel_secret;
        channelAccessToken = account.channel_access_token;
        matchedAccountId = account.id;
        break;
      }
    }
  }

  // Verify with resolved secret
  const valid = await verifySignature(channelSecret, rawBody, signature);
  if (!valid) {
    console.error('Invalid LINE signature');
    return c.json({ status: 'ok' }, 200);
  }

  const lineClient = new LineClient(channelAccessToken);
  const n8nPostbackSourceUrl = c.env.N8N_POSTBACK_SOURCE_URL;

  // 非同期処理 — LINE は ~1s 以内のレスポンスを要求
  const processingPromise = (async () => {
    for (const event of body.events) {
      try {
        await handleEvent(db, lineClient, event, channelAccessToken, matchedAccountId, c.env.WORKER_URL || new URL(c.req.url).origin, c.env.LIFF_URL, c.env);
      } catch (err) {
        console.error('Error handling webhook event:', err);
      }

      // Day0アンケート（IG流入元postback）→ n8n WF6 へ転送（既存処理に影響しないよう独立try-catchで隔離）
      try {
        await forwardPostbackSourceToN8n(event, n8nPostbackSourceUrl);
      } catch (err) {
        console.error('Failed to forward postback source to n8n WF6 (non-blocking):', err);
      }
    }
  })();

  c.executionCtx.waitUntil(processingPromise);

  return c.json({ status: 'ok' }, 200);
});

async function handleEvent(
  db: D1Database,
  lineClient: LineClient,
  event: WebhookEvent,
  lineAccessToken: string,
  lineAccountId: string | null = null,
  workerUrl?: string,
  liffUrl?: string,
  env?: Env['Bindings'],
): Promise<void> {
  if (event.type === 'follow') {
    const userId =
      event.source.type === 'user' ? event.source.userId : undefined;
    if (!userId) return;

    // プロフィール取得 & 友だち登録/更新
    let profile;
    try {
      profile = await lineClient.getProfile(userId);
    } catch (err) {
      console.error('Failed to get profile for', userId, err);
    }

    const friend = await upsertFriend(db, {
      lineUserId: userId,
      displayName: profile?.displayName ?? null,
      pictureUrl: profile?.pictureUrl ?? null,
      statusMessage: profile?.statusMessage ?? null,
    });

    // Set line_account_id for multi-account tracking
    if (lineAccountId) {
      await db.prepare('UPDATE friends SET line_account_id = ? WHERE id = ? AND line_account_id IS NULL')
        .bind(lineAccountId, friend.id).run();
    }

    // ── あいさつメッセージ: 3吹き出し（画像2枚 + テキスト） ──
    // 設計書: あいさつメッセージ実装案.md — 友だち追加直後に同時配信
    try {
      const greetingMessages = buildGreetingMessages();
      await lineClient.replyMessage(event.replyToken, greetingMessages);
      console.log(`Greeting sent: 3 bubbles to ${userId}`);

      // ログ記録
      const greetLogId = crypto.randomUUID();
      await db
        .prepare(
          `INSERT INTO messages_log (id, friend_id, direction, message_type, content, broadcast_id, scenario_step_id, delivery_type, created_at)
           VALUES (?, ?, 'outgoing', 'flex', '[greeting:3bubbles]', NULL, NULL, 'reply', ?)`,
        )
        .bind(greetLogId, friend.id, jstNow())
        .run();
    } catch (err) {
      console.error('Failed to send greeting messages', err);
    }

    // friend_add シナリオに登録（Day0はあいさつで既に送信済みなのでスキップ）
    const scenarios = await getScenarios(db);
    for (const scenario of scenarios) {
      const scenarioAccountMatch = !scenario.line_account_id || !lineAccountId || scenario.line_account_id === lineAccountId;
      if (scenario.trigger_type === 'friend_add' && scenario.is_active && scenarioAccountMatch) {
        try {
          const existing = await db
            .prepare(`SELECT id FROM friend_scenarios WHERE friend_id = ? AND scenario_id = ?`)
            .bind(friend.id, scenario.id)
            .first<{ id: string }>();
          if (!existing) {
            const friendScenario = await enrollFriendInScenario(db, friend.id, scenario.id);

            // Day0(step_order=0, delay=0)はあいさつメッセージとして既に送信済み
            // → Day1(次のステップ)から配信を開始する
            const steps = await getScenarioSteps(db, scenario.id);
            const firstStep = steps[0];
            if (firstStep && firstStep.delay_minutes === 0 && friendScenario.status === 'active') {
              // Day0をスキップしてDay1へ進める
              const secondStep = steps[1] ?? null;
              if (secondStep) {
                const nextDeliveryDate = new Date(Date.now() + 9 * 60 * 60_000);
                nextDeliveryDate.setMinutes(nextDeliveryDate.getMinutes() + secondStep.delay_minutes);
                const h = nextDeliveryDate.getUTCHours();
                if (h < 9 || h >= 21) {
                  if (h >= 21) nextDeliveryDate.setUTCDate(nextDeliveryDate.getUTCDate() + 1);
                  nextDeliveryDate.setUTCHours(9, 0, 0, 0);
                }
                await advanceFriendScenario(db, friendScenario.id, firstStep.step_order, nextDeliveryDate.toISOString().slice(0, -1) + '+09:00');
              } else {
                await completeFriendScenario(db, friendScenario.id);
              }
            }
          }
        } catch (err) {
          console.error('Failed to enroll friend in scenario', scenario.id, err);
        }
      }
    }

    // イベントバス発火: friend_add
    await fireEvent(db, 'friend_add', { friendId: friend.id, eventData: { displayName: friend.display_name } }, lineAccessToken, lineAccountId);
    return;
  }

  if (event.type === 'unfollow') {
    const userId =
      event.source.type === 'user' ? event.source.userId : undefined;
    if (!userId) return;

    await updateFriendFollowStatus(db, userId, false);
    return;
  }

  if (event.type === 'message' && event.message.type === 'text') {
    const textMessage = event.message as TextEventMessage;
    const userId =
      event.source.type === 'user' ? event.source.userId : undefined;
    if (!userId) return;

    let friend = await getFriendByLineUserId(db, userId);
    if (!friend) {
      // 友だち未登録の場合は自動登録（既存友だちがWebhook切替前に追加されたケース）
      let profile;
      try {
        profile = await lineClient.getProfile(userId);
      } catch (err) {
        console.error('Failed to get profile for', userId, err);
      }
      friend = await upsertFriend(db, {
        lineUserId: userId,
        displayName: profile?.displayName ?? null,
        pictureUrl: profile?.pictureUrl ?? null,
        statusMessage: profile?.statusMessage ?? null,
      });
      console.log('Auto-registered friend from message event:', userId, friend.id);

      // friend_add シナリオにも登録（簡易版）
      try {
        const scenarioRows = await db.prepare(
          `SELECT id FROM scenarios WHERE trigger_type = 'friend_add' AND is_active = 1`
        ).all<{ id: string }>();
        for (const s of scenarioRows.results) {
          try {
            await enrollFriendInScenario(db, friend.id, s.id);
          } catch (err) {
            console.error('Failed to enroll friend in scenario:', s.id, err);
          }
        }
      } catch (err) {
        console.error('Failed to get scenarios for auto-enroll:', err);
      }

      // イベントバス発火
      try {
        await fireEvent(db, 'friend_add', { friendId: friend.id, eventData: { displayName: friend.display_name } }, lineAccessToken, lineAccountId);
      } catch (err) {
        console.error('Failed to fire friend_add event:', err);
      }
    }

    const incomingText = textMessage.text;
    const now = jstNow();
    const logId = crypto.randomUUID();

    // 受信メッセージをログに記録
    await db
      .prepare(
        `INSERT INTO messages_log (id, friend_id, direction, message_type, content, broadcast_id, scenario_step_id, created_at)
         VALUES (?, ?, 'incoming', 'text', ?, NULL, NULL, ?)`,
      )
      .bind(logId, friend.id, incomingText, now)
      .run();

    // チャットを作成/更新（ユーザーの自発的メッセージのみ unread にする）
    // ボタンタップ等の自動応答キーワードは除外
    const autoKeywords = ['料金', '機能', 'API', 'フォーム', 'ヘルプ', 'UUID', 'UUID連携について教えて', 'UUID連携を確認', '配信時間', '導入支援を希望します', 'アカウント連携を見る', '体験を完了する', 'BAN対策を見る', '連携確認'];
    const isAutoKeyword = autoKeywords.some(k => incomingText === k);
    const isTimeCommand = /(?:配信時間|配信|届けて|通知)[はを]?\s*\d{1,2}\s*時/.test(incomingText);
    if (!isAutoKeyword && !isTimeCommand) {
      await upsertChatOnMessage(db, friend.id);
    }

    // 配信時間設定: 「配信時間は○時」「○時に届けて」等のパターンを検出
    const timeMatch = incomingText.match(/(?:配信時間|配信|届けて|通知)[はを]?\s*(\d{1,2})\s*時/);
    if (timeMatch) {
      const hour = parseInt(timeMatch[1], 10);
      if (hour >= 6 && hour <= 22) {
        // Save preferred_hour to friend metadata
        const existing = await db.prepare('SELECT metadata FROM friends WHERE id = ?').bind(friend.id).first<{ metadata: string }>();
        const meta = JSON.parse(existing?.metadata || '{}');
        meta.preferred_hour = hour;
        await db.prepare('UPDATE friends SET metadata = ?, updated_at = ? WHERE id = ?')
          .bind(JSON.stringify(meta), jstNow(), friend.id).run();

        // Reply with confirmation
        try {
          const period = hour < 12 ? '午前' : '午後';
          const displayHour = hour <= 12 ? hour : hour - 12;
          await lineClient.replyMessage(event.replyToken, [
            buildMessage('flex', JSON.stringify({
              type: 'bubble', size: 'mega',
              body: { type: 'box', layout: 'vertical', paddingAll: '0px', contents: [
                { type: 'image', url: 'https://rin-assets.pages.dev/banner.jpg', size: 'full', aspectRatio: '2:3', aspectMode: 'cover' },
                { type: 'box', layout: 'vertical', position: 'absolute', offsetTop: '0px', offsetBottom: '0px', offsetStart: '0px', offsetEnd: '0px',
                  background: { type: 'linearGradient', angle: '0deg', startColor: '#0B0E2A44', centerColor: '#0B0E2A99', endColor: '#0B0E2Add' },
                  paddingAll: '24px', justifyContent: 'center', contents: [
                    { type: 'text', text: '配信時間を設定しました', size: 'md', weight: 'bold', color: '#C9B77D' },
                    { type: 'separator', color: '#C9B77D44', margin: 'lg' },
                    { type: 'text', text: `${period} ${displayHour}:00`, size: 'xxl', weight: 'bold', color: '#f5f0e8', align: 'center', margin: 'xl' },
                    { type: 'text', text: `（${hour}:00〜）`, size: 'sm', color: '#d0c8e0', align: 'center', margin: 'sm' },
                    { type: 'text', text: '今後のステップ配信は\nこの時間以降にお届けします。', size: 'xs', color: '#A8A0B8', wrap: true, margin: 'xl' },
                  ]},
              ]},
            })),
          ]);
        } catch (err) {
          console.error('Failed to reply for time setting', err);
        }
        return;
      }
    }

    // Cross-account trigger: send message from another account via UUID
    if (incomingText === '体験を完了する' && lineAccountId) {
      try {
        const friendRecord = await db.prepare('SELECT user_id FROM friends WHERE id = ?').bind(friend.id).first<{ user_id: string | null }>();
        if (friendRecord?.user_id) {
          // Find the same user on other accounts
          const otherFriends = await db.prepare(
            'SELECT f.line_user_id, la.channel_access_token FROM friends f INNER JOIN line_accounts la ON la.id = f.line_account_id WHERE f.user_id = ? AND f.line_account_id != ? AND f.is_following = 1'
          ).bind(friendRecord.user_id, lineAccountId).all<{ line_user_id: string; channel_access_token: string }>();

          for (const other of otherFriends.results) {
            const otherClient = new LineClient(other.channel_access_token);
            const { buildMessage: bm } = await import('../services/step-delivery.js');
            await otherClient.pushMessage(other.line_user_id, [bm('flex', JSON.stringify({
              type: 'bubble', size: 'giga',
              header: { type: 'box', layout: 'vertical', paddingAll: '20px', backgroundColor: '#fffbeb',
                contents: [{ type: 'text', text: `${friend.display_name || ''}さんへ`, size: 'lg', weight: 'bold', color: '#1e293b' }],
              },
              body: { type: 'box', layout: 'vertical', paddingAll: '20px',
                contents: [
                  { type: 'text', text: '別アカウントからのアクションを検知しました。', size: 'sm', color: '#06C755', weight: 'bold', wrap: true },
                  { type: 'text', text: 'アカウント連携が正常に動作しています。体験ありがとうございました。', size: 'sm', color: '#1e293b', wrap: true, margin: 'md' },
                  { type: 'separator', margin: 'lg' },
                  { type: 'text', text: 'ステップ配信・フォーム即返信・アカウント連携・リッチメニュー・自動返信 — 全て無料、全てOSS。', size: 'xs', color: '#64748b', wrap: true, margin: 'lg' },
                ],
              },
              footer: { type: 'box', layout: 'vertical', paddingAll: '16px',
                contents: [
                  { type: 'button', action: { type: 'message', label: '導入について相談する', text: '導入支援を希望します' }, style: 'primary', color: '#06C755' },
                  ...(liffUrl ? [{ type: 'button', action: { type: 'uri', label: 'フィードバックを送る', uri: `${liffUrl}?page=form` }, style: 'secondary', margin: 'sm' }] : []),
                ],
              },
            }))]);
          }

          // Reply on Account ② confirming
          await lineClient.replyMessage(event.replyToken, [buildMessage('flex', JSON.stringify({
            type: 'bubble',
            body: { type: 'box', layout: 'vertical', paddingAll: '20px',
              contents: [
                { type: 'text', text: 'Account ① にメッセージを送りました', size: 'sm', color: '#06C755', weight: 'bold', align: 'center' },
                { type: 'text', text: 'Account ① のトーク画面を確認してください', size: 'xs', color: '#64748b', align: 'center', margin: 'md' },
              ],
            },
          }))]);
          return;
        }
      } catch (err) {
        console.error('Cross-account trigger error:', err);
      }
    }

    // ── エスカレーション検出（最優先・カテゴリ別に挙動分岐） ──
    // 2026-05-24 v2: safety/refund/claim は応答停止+通知、medical_consult は metadata + 通知のみ（応答止めない）
    // 設計参照: 占い事業/LINE/2026-05-24_クレーム返金体調エスカレーション設計.md
    const escalationCategory = detectEscalation(incomingText);
    if (escalationCategory) {
      const behavior = getEscalationBehavior(escalationCategory);
      try {
        // 1. friend metadata に escalation_pending を記録（safety/refund/claim のみ・既存値とマージ）
        if (behavior.pauseDelivery) {
          const friendRow = await db.prepare('SELECT metadata FROM friends WHERE id = ?')
            .bind(friend.id).first<{ metadata: string }>();
          const existingMeta = JSON.parse(friendRow?.metadata || '{}') as Record<string, unknown>;
          const mergedMeta = {
            ...existingMeta,
            escalation_pending: true,
            escalation_category: escalationCategory,
            escalation_at: jstNow(),
          };
          await db.prepare('UPDATE friends SET metadata = ?, updated_at = ? WHERE id = ?')
            .bind(JSON.stringify(mergedMeta), jstNow(), friend.id).run();

          // 配信中シナリオを一時停止（safety/refund/claim のみ）
          // safety検出後にDay自動配信が届くと事故になるため必須
          await db.prepare(
            `UPDATE friend_scenarios SET status = 'paused', updated_at = ? WHERE friend_id = ? AND status = 'active'`,
          ).bind(jstNow(), friend.id).run();
        } else {
          // medical_consult: metadata だけマーク（配信は止めない）
          const friendRow = await db.prepare('SELECT metadata FROM friends WHERE id = ?')
            .bind(friend.id).first<{ metadata: string }>();
          const existingMeta = JSON.parse(friendRow?.metadata || '{}') as Record<string, unknown>;
          const mergedMeta = {
            ...existingMeta,
            medical_consult_at: jstNow(),
          };
          await db.prepare('UPDATE friends SET metadata = ?, updated_at = ? WHERE id = ?')
            .bind(JSON.stringify(mergedMeta), jstNow(), friend.id).run();
        }

        // 2. 運営者へ通知（Discord webhook・未設定なら no-op）
        await notifyEscalation(
          { ESCALATION_DISCORD_WEBHOOK: env?.ESCALATION_DISCORD_WEBHOOK },
          {
            category: escalationCategory,
            friendId: friend.id,
            friendDisplayName: friend.display_name,
            incomingText,
            receivedAt: jstNow(),
            notifyLevel: behavior.notifyLevel,
          },
        );

        // 3. ユーザーへの最小応答 + 後段停止（safety/refund/claim のみ）
        if (behavior.replyToUser) {
          await lineClient.replyMessage(event.replyToken, [buildAcknowledgeMessage(escalationCategory)]);

          // 早期return前に message_received fireEvent（後段の line 492 fire を肩代わり）
          await fireEvent(db, 'message_received', {
            friendId: friend.id,
            eventData: { text: incomingText, escalation: ESCALATION_LABELS[escalationCategory] },
          }, lineAccessToken, lineAccountId);

          return;
        }
        // medical_consult は応答せず後段の通常処理に流す（fall-through）
      } catch (err) {
        console.error('Escalation handling error:', err);
        // 通知失敗してもメッセージ受信処理は止めない
      }
    }

    // ── 診断Bot処理（2026-05-24 DEPRECATED・consumed=false で後段に流す） ──
    const diagnosisResult = await handleDiagnosisMessage(db, friend.id, incomingText);
    if (diagnosisResult.consumed) {
      try {
        await lineClient.replyMessage(event.replyToken, diagnosisResult.messages);

        // 送信ログ
        for (const msg of diagnosisResult.messages) {
          const outLogId = crypto.randomUUID();
          await db
            .prepare(
              `INSERT INTO messages_log (id, friend_id, direction, message_type, content, broadcast_id, scenario_step_id, delivery_type, created_at)
               VALUES (?, ?, 'outgoing', ?, ?, NULL, NULL, 'reply', ?)`,
            )
            .bind(outLogId, friend.id, msg.type, JSON.stringify(msg), jstNow())
            .run();
        }
      } catch (err) {
        console.error('Failed to send diagnosis reply', err);
      }

      // イベントバス発火
      await fireEvent(db, 'message_received', {
        friendId: friend.id,
        eventData: { text: incomingText, matched: true, diagnosis: diagnosisResult.diagnosisType || true },
      }, lineAccessToken, lineAccountId);
      return;
    }

    // 自動返信チェック（このアカウントのルール + グローバルルールのみ）
    // NOTE: Auto-replies use replyMessage (free, no quota) instead of pushMessage
    // The replyToken is only valid for ~1 minute after the message event
    const autoReplies = await db
      .prepare(`SELECT * FROM auto_replies WHERE is_active = 1 AND (line_account_id IS NULL${lineAccountId ? ` OR line_account_id = '${lineAccountId}'` : ''}) ORDER BY created_at ASC`)
      .all<{
        id: string;
        keyword: string;
        match_type: 'exact' | 'contains';
        response_type: string;
        response_content: string;
        is_active: number;
        created_at: string;
      }>();

    let matched = false;
    for (const rule of autoReplies.results) {
      const isMatch =
        rule.match_type === 'exact'
          ? incomingText === rule.keyword
          : incomingText.includes(rule.keyword);

      if (isMatch) {
        try {
          // Expand template variables ({{name}}, {{uid}}, {{auth_url:CHANNEL_ID}})
          const expandedContent = expandVariables(rule.response_content, friend as { id: string; display_name: string | null; user_id: string | null }, workerUrl);
          const replyMsg = buildMessage(rule.response_type, expandedContent);
          await lineClient.replyMessage(event.replyToken, [replyMsg]);

          // 送信ログ（replyMessage = 無料）
          const outLogId = crypto.randomUUID();
          await db
            .prepare(
              `INSERT INTO messages_log (id, friend_id, direction, message_type, content, broadcast_id, scenario_step_id, delivery_type, created_at)
               VALUES (?, ?, 'outgoing', ?, ?, NULL, NULL, 'reply', ?)`,
            )
            .bind(outLogId, friend.id, rule.response_type, rule.response_content, jstNow())
            .run();
        } catch (err) {
          console.error('Failed to send auto-reply', err);
        }

        matched = true;
        break;
      }
    }

    // イベントバス発火: message_received
    await fireEvent(db, 'message_received', {
      friendId: friend.id,
      eventData: { text: incomingText, matched },
    }, lineAccessToken, lineAccountId);

    return;
  }
}

/**
 * Day0アンケート postback → n8n WF6 forward
 * 対象: event.type === 'postback' && event.postback.data === 'src=ig_bio' | 'src=ig_highlight' | 'src=other'
 * n8n WF6 で Sheets顧客台帳の source 列に upsert する。
 *
 * - 既存webhook処理に影響しないよう独立try-catchで隔離（呼び出し元）
 * - N8N_POSTBACK_SOURCE_URL 未設定時は no-op（ローカル/テスト環境を考慮）
 * - 対象外のpostback（src= 以外）はスキップ
 * - ネットワーク失敗・n8n側エラーも握り潰す（postback応答済みのため再送不要）
 */
const POSTBACK_SOURCE_VALUES = new Set(['src=ig_bio', 'src=ig_highlight', 'src=other']);

async function forwardPostbackSourceToN8n(
  event: WebhookEvent,
  n8nUrl: string | undefined,
): Promise<void> {
  if (!n8nUrl) return;
  if (event.type !== 'postback') return;

  const data = (event as { postback?: { data?: string } }).postback?.data ?? '';
  if (!POSTBACK_SOURCE_VALUES.has(data)) return;

  const userId = event.source.type === 'user' ? event.source.userId : undefined;
  if (!userId) return;

  const payload = {
    userId,
    data,
    timestamp: new Date().toISOString(),
  };

  const res = await fetch(n8nUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    console.error(`n8n WF6 forward failed: status=${res.status}`);
  }
}

/**
 * あいさつメッセージ: 3吹き出し構成
 * 設計参照: 占い事業/LINE/あいさつメッセージ実装案.md
 *
 * 1. 画像: 世界観訴求（背景画像+テキスト中央配置）
 * 2. テキスト: 診断の受け方（LINE標準テキスト）
 * 3. テキスト: Day0（LINE標準テキスト）
 */
import type { Message } from '@line-crm/line-sdk';

function buildGreetingMessages(): Message[] {
  // 吹き出し1: 世界観画像（背景+テキスト上下中央配置）
  const image1: Message = {
    type: 'flex',
    altText: '優しいのに進まない関係を、鏡の湖で整える場所です。',
    contents: {
      type: 'bubble',
      size: 'mega',
      body: {
        type: 'box',
        layout: 'vertical',
        paddingAll: '0px',
        contents: [
          {
            type: 'image',
            url: 'https://master.rin-assets.pages.dev/greeting-bg.jpg',
            size: 'full',
            aspectRatio: '2:3',
            aspectMode: 'cover',
          },
          {
            type: 'box',
            layout: 'vertical',
            position: 'absolute',
            offsetTop: '0px',
            offsetBottom: '0px',
            offsetStart: '0px',
            offsetEnd: '0px',
            background: {
              type: 'linearGradient',
              angle: '0deg',
              startColor: '#0B0E2A88',
              centerColor: '#0B0E2A66',
              endColor: '#0B0E2A88',
            },
            paddingAll: '28px',
            justifyContent: 'center',
            alignItems: 'center',
            contents: [
              { type: 'text', text: '凛', size: 'sm', color: '#C9B77D', align: 'center', weight: 'bold' },
              { type: 'text', text: '優しいのに進まない関係を\n鏡の湖で、まず整える', size: 'xxl', weight: 'bold', color: '#F0F0F5', align: 'center', margin: 'xl', wrap: true },
              { type: 'separator', color: '#C9B77D44', margin: 'xl' },
              { type: 'text', text: '彼の気持ちより、\n行動・約束の置き方を見る場所。', size: 'md', color: '#A8A0B8', wrap: true, align: 'center', margin: 'xl' },
              { type: 'text', text: '3-12か月の境界期間を、\nひとりで抱えなくていい。', size: 'sm', color: '#C9B77D', align: 'center', margin: 'xl', wrap: true },
              { type: 'text', text: '明日から、判断軸の話を届けます', size: 'sm', color: '#A8A0B8', align: 'center', margin: 'sm' },
            ],
          },
        ],
      },
    },
  } as unknown as Message;

  // 吹き出し2: LINEで届くもの（LINE標準テキスト）
  // 2026-05-24 更新: 旧「最初の診断の受け取り方（湖キーワード送信フロー）」を廃止し、
  // Day0-Day7 教育配信＋商品案内の予告に書き換え。
  const text2: Message = {
    type: 'text',
    text: `このLINEで届くもの

1. 数日に分けて、判断軸の話（気持ちより行動 / 進む・待つ・手放す）を届けます
2. 軽く試したい方には、鏡の湖ミニ鑑定 ¥480 をご案内します
3. 本格的に整理したい方には、表と裏の恋鑑定 ¥4,980 をご案内します

凛は急がせません。
まずは読むだけでOKです。`,
  } as Message;

  // 吹き出し3: Day0テキスト（LINE標準テキスト）
  const text3: Message = {
    type: 'text',
    text: `縁がつながりましたね。
ここは、30代の優しいのに進まない関係を、鏡の湖で整える場所です。

連絡はある。
会えばやさしい。
でも、結婚の話が出ない。
次の約束が曖昧なまま、32歳や33歳の時間だけが進んでいく。

そんな夜に、凛はいます。

凛が見るのは、彼の気持ちを当てることではありません。
気持ちより、行動・約束の置き方を見ます。
鏡の湖が、表と裏のズレを映すからです。

ここでは、進む・待つ・手放すを自分で選べる軸を作ります。
急いで決めなくて大丈夫。
まずは読むだけでOKです。

このあと数日に分けて、
「なぜこんなに苦しいのか」
「好意の有無だけでは足りない理由」
「結婚の話が止まる構造」
を順に届けます。

必要になった時だけ、関係整理の入口も置いておきます。
凛は急がせません。`,
  } as Message;

  return [image1, text2, text3];
}

export { webhook };
