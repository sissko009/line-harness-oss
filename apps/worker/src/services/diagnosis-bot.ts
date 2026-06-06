/**
 * 診断Bot — 凛のLINE 4タイプ診断
 *
 * LINE標準テキスト + QuickReply。
 * 文面は読みやすさ重視（改行を減らし、段落でまとめる）。
 * 絵文字は凛の世界観に合うものを控えめに（🌙✨🪞）。
 *
 * 設計参照:
 *   - 占い事業/LINE/LINE運用計画書.md Section 4
 *   - 占い事業/LINE/診断Bot設計_質問分岐結果文.md
 */

import { jstNow } from '@line-crm/db';
import type { Message } from '@line-crm/line-sdk';

// ── 型定義 ──

export type DiagnosisType =
  | 'kimochi_maigo'
  | 'renraku_teishi'
  | 'aimai_teitai'
  | 'fukuen_shuchaku';

export const DIAGNOSIS_TYPE_LABELS: Record<DiagnosisType, string> = {
  kimochi_maigo:   '彼の気持ち迷子型',
  renraku_teishi:  '連絡停止不安型',
  aimai_teitai:    '曖昧関係停滞型',
  fukuen_shuchaku: '復縁執着型',
};

export const DIAGNOSIS_TAG_NAMES: Record<DiagnosisType, string> = {
  kimochi_maigo:   '診断:彼の気持ち迷子型',
  renraku_teishi:  '診断:連絡停止不安型',
  aimai_teitai:    '診断:曖昧関係停滞型',
  fukuen_shuchaku: '診断:復縁執着型',
};

interface DiagnosisState {
  step: 'q1' | 'q2' | 'q3';
  q1?: number;
  q2?: number;
}

// ── QuickReply付きテキスト ──

function textWithQR(text: string, items: { label: string; text: string }[]): Message {
  return {
    type: 'text',
    text,
    quickReply: {
      items: items.map(item => ({
        type: 'action',
        action: { type: 'message', label: item.label, text: item.text },
      })),
    },
  } as unknown as Message;
}

// ── 質問メッセージ ──

function buildQ1(): Message {
  return textWithQR(
    `鏡の湖が、いまの現在地を映します。

いま一番苦しいのは、どれに近いですか。`,
    [
      { label: '彼の気持ちが見えない', text: '1' },
      { label: '連絡が減ると不安', text: '2' },
      { label: 'やさしいのに進まない', text: '3' },
      { label: '終わったはずなのに引きずる', text: '4' },
    ],
  );
}

function buildQ2(): Message {
  return textWithQR(
    '関係が止まりやすい場面は、どこですか。',
    [
      { label: '結婚の話が出ない', text: '1' },
      { label: '次の約束が曖昧', text: '2' },
      { label: '同棲中なのに進まない', text: '3' },
      { label: '会えない時間に考えすぎる', text: '4' },
    ],
  );
}

function buildQ3(): Message {
  return textWithQR(
    'いま、どれくらい急いで判断したいですか。',
    [
      { label: '今月中に整理したい', text: '1' },
      { label: '30日くらい観察したい', text: '2' },
      { label: '進む / 待つ / 手放す', text: '3' },
    ],
  );
}

// ── タイプ分類 ──

function classifyType(q1: number): DiagnosisType {
  switch (q1) {
    case 1: return 'kimochi_maigo';
    case 2: return 'renraku_teishi';
    case 3: return 'aimai_teitai';
    case 4: return 'fukuen_shuchaku';
    default: return 'kimochi_maigo';
  }
}

// ── ミニ鑑定結果テキスト ──

function buildResultText(type: DiagnosisType, _q3: number): string {
  const results: Record<DiagnosisType, string> = {
    kimochi_maigo: `鏡の湖は、あなたが「好きかどうか」の答えだけを探して、苦しさを深くしていると映しています。
31歳や32歳の恋では、気持ちの有無だけでなく、結婚の話が出るか、次の約束が置かれるかを見る方が判断しやすいことがあります。
気持ちより、行動・約束の置き方を見ます。
いまの一手は、\`待つ\` ではなく「観察する待ち方」に近いです。`,

    renraku_teishi: `鏡の湖は、夜のLINEで不安が大きくなりやすい状態を映しています。
返信の速さだけで答えを出そうとすると、表と裏のズレを見誤りやすくなります。
見るべきなのは、翌日の行動差と、約束の具体度です。
いまの一手は、\`待つ\` を選びつつ、夜ではなく昼の現実を見ることです。`,

    aimai_teitai: `鏡の湖は、やさしさはあるのに進展の意思が弱い関係を映しています。
同棲しているのに次の段階へ進まない、あるいは3年近く続いているのに家族紹介の話が出ない時、この型が出やすいです。
凛は急がせませんが、止まり方の種類は見分けます。
いまの一手は、\`進む\` と \`待つ\` の境目を観察し直すことです。`,

    fukuen_shuchaku: `鏡の湖は、過去の痛みが今の判断を曇らせていると映しています。
終わった関係をすぐ否定する必要はありません。
ただ、戻りたい気持ちと、戻ってもまた苦しいかもしれない感覚を分けて見る必要があります。
いまの一手は、\`手放す\` を急ぐことではなく、何をまだ握っているかを言葉にすることです。`,
  };
  return results[type];
}

// ── CTA ──

function buildCtaMessage(): Message {
  return textWithQR(
    `読むだけで終えても大丈夫です。
もう少し現在地を整えたい方は、関係整理の入口である「表と裏の恋鑑定（¥4,980）」をご覧ください。`,
    [
      { label: '読むだけで終える', text: '月の便りを待つ' },
      { label: '鑑定を見る', text: '凛に見てもらう' },
    ],
  );
}

// ── メイン処理 ──

export interface DiagnosisBotResult {
  messages: Message[];
  diagnosisType?: DiagnosisType;
  consumed: boolean;
}

// ─────────────────────────────────────────────────────────
// DEPRECATED 2026-05-24: LINE上の無料診断Bot（「湖」キーワード対話型診断）は廃止。
// LINEは「教育・導線・宣伝」のみに絞る方針変更（こっさん指示）。
// 本関数は no-op（消費せず後段の自動返信/ステップ配信へ流す）。
// 質問文・分類ルール・結果文の文章資産は履歴として残す。
// 参照: 占い事業/00_戦略/2026-05-24_LINE無料診断Bot廃止_本番反映指示書.md
// ─────────────────────────────────────────────────────────

const DIAGNOSIS_BOT_ENABLED = false;

export async function handleDiagnosisMessage(
  db: D1Database,
  friendId: string,
  incomingText: string,
): Promise<DiagnosisBotResult> {
  if (!DIAGNOSIS_BOT_ENABLED) {
    return { messages: [], consumed: false };
  }

  const row = await db.prepare('SELECT metadata FROM friends WHERE id = ?')
    .bind(friendId).first<{ metadata: string }>();
  const metadata = JSON.parse(row?.metadata || '{}') as Record<string, unknown>;
  const state = metadata.diagnosis_state as DiagnosisState | undefined;

  if (incomingText === '湖') {
    return {
      messages: [{ type: 'text', text: `凛の「湖」診断は、いまは止めています。\n\nここで見るのは、彼の気持ちを当てることではなく、あなたが感じた違和感と、言葉と行動のズレです。\n\n凛は急がせません。\nまずはDay0からDay7の言葉を、読むだけで大丈夫です。` } as Message],
      consumed: true,
    };
  }

  if (incomingText === '月の便りを待つ') {
    return {
      messages: [{ type: 'text', text: `わかりました。\n\n凛は急がせません。\n明日から少しずつ、関係の現在地を整えるための言葉を届けます。\nまずは読むだけで大丈夫です。` } as Message],
      consumed: true,
    };
  }

  if (incomingText === '凛に見てもらう') {
    return {
      messages: [{ type: 'text', text: `表と裏の恋鑑定では、次の6点を返します。

- 言葉と行動のズレ
- この恋の現在地
- 一番大きい停滞要因
- 今やらない方がいいこと
- 直近7日で見るサイン
- 30日判断の入口

気持ちより、行動・約束の置き方を見ます。
読むだけで終えても大丈夫です。
必要な方だけ、関係整理の入口としてご覧ください。

▼ 詳しくはこちら
https://rin-tarot-web.vercel.app/?utm_source=line&utm_medium=diagnosis_cta` } as Message],
      consumed: true,
    };
  }

  if (!state) return { messages: [], consumed: false };

  const answer = parseInt(incomingText, 10);
  if (isNaN(answer) || answer < 1 || answer > 4) {
    delete metadata.diagnosis_state;
    await updateMetadata(db, friendId, metadata);
    return { messages: [], consumed: false };
  }

  if (state.step === 'q1') {
    metadata.diagnosis_state = { step: 'q2', q1: answer } as DiagnosisState;
    await updateMetadata(db, friendId, metadata);
    return { messages: [buildQ2()], consumed: true };
  }

  if (state.step === 'q2') {
    metadata.diagnosis_state = { step: 'q3', q1: state.q1!, q2: answer } as DiagnosisState;
    await updateMetadata(db, friendId, metadata);
    return { messages: [buildQ3()], consumed: true };
  }

  if (state.step === 'q3') {
    const diagnosisType = classifyType(state.q1!);
    metadata.diagnosis_type = diagnosisType;
    metadata.diagnosis_q3 = answer;
    metadata.diagnosis_completed_at = jstNow();
    delete metadata.diagnosis_state;
    await updateMetadata(db, friendId, metadata);
    await ensureDiagnosisTag(db, friendId, diagnosisType);

    return {
      messages: [
        { type: 'text', text: buildResultText(diagnosisType, answer) } as Message,
        buildCtaMessage(),
      ],
      diagnosisType,
      consumed: true,
    };
  }

  return { messages: [], consumed: false };
}

async function updateMetadata(db: D1Database, friendId: string, metadata: Record<string, unknown>): Promise<void> {
  await db.prepare('UPDATE friends SET metadata = ?, updated_at = ? WHERE id = ?')
    .bind(JSON.stringify(metadata), jstNow(), friendId).run();
}

async function ensureDiagnosisTag(db: D1Database, friendId: string, type: DiagnosisType): Promise<void> {
  const tagName = DIAGNOSIS_TAG_NAMES[type];
  let tag = await db.prepare('SELECT id FROM tags WHERE name = ?').bind(tagName).first<{ id: string }>();
  if (!tag) {
    const tagId = crypto.randomUUID();
    const colors: Record<DiagnosisType, string> = {
      kimochi_maigo: '#8B5CF6', renraku_teishi: '#EF4444',
      aimai_teitai: '#F59E0B', fukuen_shuchaku: '#6366F1',
    };
    await db.prepare('INSERT INTO tags (id, name, color, created_at) VALUES (?, ?, ?, ?)')
      .bind(tagId, tagName, colors[type], jstNow()).run();
    tag = { id: tagId };
  }
  for (const name of Object.values(DIAGNOSIS_TAG_NAMES)) {
    const oldTag = await db.prepare('SELECT id FROM tags WHERE name = ?').bind(name).first<{ id: string }>();
    if (oldTag) await db.prepare('DELETE FROM friend_tags WHERE friend_id = ? AND tag_id = ?').bind(friendId, oldTag.id).run();
  }
  await db.prepare('INSERT OR IGNORE INTO friend_tags (friend_id, tag_id, assigned_at) VALUES (?, ?, ?)').bind(friendId, tag.id, jstNow()).run();
}
