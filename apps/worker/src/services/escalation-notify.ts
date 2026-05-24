/**
 * エスカレーション通知
 *
 * detectEscalation がヒットした時に、こっさん（運営者）へ通知する。
 *
 * 実装方針:
 *   - Discord webhook 経由を第一選択（リアルタイム性）
 *   - 環境変数 ESCALATION_DISCORD_WEBHOOK が未設定なら no-op（dev環境想定）
 *   - 通知失敗は throw せず console.error（メッセージ受信処理を止めない）
 *
 * 設計参照: 占い事業/LINE/2026-05-24_クレーム返金体調エスカレーション設計.md §5
 */

import type { EscalationCategory } from './escalation-detector.js';
import { ESCALATION_LABELS } from './escalation-detector.js';

export interface EscalationContext {
  category: EscalationCategory;
  friendId: string;
  friendDisplayName?: string | null;
  incomingText: string;
  receivedAt: string; // ISO 8601 (JST)
  /** 通知の温度（urgent: @here付き赤 / normal: 黄色 / digest: 控え目グレー） */
  notifyLevel?: 'urgent' | 'normal' | 'digest';
}

/**
 * Discord webhook の payload を組み立てる。
 */
function buildDiscordPayload(ctx: EscalationContext): Record<string, unknown> {
  const level = ctx.notifyLevel ?? (ctx.category === 'safety' ? 'urgent' : 'normal');
  const color = level === 'urgent' ? 0xff4444 : level === 'normal' ? 0xffaa00 : 0x808080;
  const truncated = ctx.incomingText.length > 500
    ? ctx.incomingText.slice(0, 500) + '...'
    : ctx.incomingText;

  return {
    content: level === 'urgent' ? '@here **凛LINE 安全相談を検知**' : undefined,
    embeds: [{
      title: `凛LINE エスカレーション: ${ESCALATION_LABELS[ctx.category]}`,
      color,
      fields: [
        { name: 'カテゴリ', value: ESCALATION_LABELS[ctx.category], inline: true },
        { name: '通知温度', value: level, inline: true },
        { name: '受信時刻', value: ctx.receivedAt, inline: true },
        { name: 'friend ID', value: `\`${ctx.friendId}\``, inline: false },
        { name: '表示名', value: ctx.friendDisplayName || '(未設定)', inline: false },
        { name: '受信内容', value: '```\n' + truncated + '\n```', inline: false },
      ],
      footer: {
        text: level === 'urgent' ? '最優先で対応してください'
          : level === 'normal' ? '通常エスカレーション・営業時間内に対応'
          : '日次ダイジェスト確認案件',
      },
    }],
  };
}

/**
 * Discord に通知。失敗してもメッセージ受信処理は止めない。
 *
 * @param env Cloudflare Worker env （ESCALATION_DISCORD_WEBHOOK を含む）
 * @param ctx エスカレーション情報
 */
export async function notifyEscalation(
  env: { ESCALATION_DISCORD_WEBHOOK?: string },
  ctx: EscalationContext,
): Promise<void> {
  const webhookUrl = env.ESCALATION_DISCORD_WEBHOOK;
  if (!webhookUrl) {
    // 環境変数未設定（dev環境等）→ no-op
    console.log('[escalation-notify] ESCALATION_DISCORD_WEBHOOK not set; skipping notify', {
      category: ctx.category,
      friendId: ctx.friendId,
    });
    return;
  }

  try {
    const payload = buildDiscordPayload(ctx);
    const res = await fetch(webhookUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      const body = await res.text().catch(() => '');
      console.error('[escalation-notify] Discord webhook failed', { status: res.status, body });
    }
  } catch (err) {
    console.error('[escalation-notify] notifyEscalation error', err);
  }
}
