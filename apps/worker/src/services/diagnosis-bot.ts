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
    `🌙 湖の水面が、少し揺れました。

まず、今いちばん苦しいものを教えてください。`,
    [
      { label: '彼の気持ちがわからない', text: '1' },
      { label: '連絡が来ない/返信が止まる', text: '2' },
      { label: '会えるのに進展しない', text: '3' },
      { label: '別れたのに忘れられない', text: '4' },
    ],
  );
}

function buildQ2(): Message {
  return textWithQR(
    '次に、今の関係に近いものを選んでください 🪞',
    [
      { label: '連絡はある', text: '1' },
      { label: '連絡が止まっている', text: '2' },
      { label: '会えるけど曖昧', text: '3' },
      { label: 'もう別れている', text: '4' },
    ],
  );
}

function buildQ3(): Message {
  return textWithQR(
    `✨ 凛の瞳が、紫に変わりかけています。

最後に、今いちばん知りたいのはどれですか？`,
    [
      { label: '彼の本音', text: '1' },
      { label: 'この恋が止まっている理由', text: '2' },
      { label: '待つべきか動くべきか', text: '3' },
      { label: 'まだ可能性があるか', text: '4' },
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

// ── Q3分岐のカスタム一文 ──

const Q3_LINES: Record<DiagnosisType, Record<number, string>> = {
  kimochi_maigo: {
    1: 'あなたが知りたいのは態度の裏にある本音。それは表情ではなく、距離の取り方に出ます。',
    2: 'あなたが知りたいのは、なぜ動けないのか。その理由は彼だけにあるとは限りません。',
    3: 'あなたが知りたいのは次の一手。でもその前に、見るべきものがあります。',
    4: 'あなたが知りたいのは未来。でも可能性は「ある/ない」では測れません。',
  },
  renraku_teishi: {
    1: 'あなたが知りたいのは沈黙の裏の本音。返事がないことと、気持ちがないことは違います。',
    2: 'あなたが知りたいのは、なぜ途切れたのか。連絡が止まる時には、止まる理由があります。',
    3: 'あなたが知りたいのは、待つべきか動くべきか。その判断には、途切れ方の癖を見る必要があります。',
    4: 'あなたが知りたいのは、まだ戻れるのか。沈黙の長さと、縁の深さは別のものです。',
  },
  aimai_teitai: {
    1: 'あなたが知りたいのは、相手の本当の気持ち。会えることと、進む気があることは違います。',
    2: 'あなたが知りたいのは、なぜ進まないのか。曖昧さには、曖昧である理由が隠れています。',
    3: 'あなたが知りたいのは、ここから動くべきか。その前に、この関係に名前をつける必要があります。',
    4: 'あなたが知りたいのは、この先があるのか。曖昧な関係の先には、2つの道しかありません。',
  },
  fukuen_shuchaku: {
    1: 'あなたが知りたいのは、相手にまだ気持ちがあるか。終わった恋と、終わっていない縁は別のものです。',
    2: 'あなたが知りたいのは、なぜ手放せないのか。未練と、未完了の感情は似ていて全く違います。',
    3: 'あなたが知りたいのは、追うべきか手放すべきか。でもその問い自体が、まだ答えを出せない証拠です。',
    4: 'あなたが知りたいのは、復縁の可能性。でも戻ることと、やり直すことは全く違う道です。',
  },
};

// ── 「まだ見えていないもの」 ──

const UNSEEN: Record<DiagnosisType, string> = {
  kimochi_maigo:   'でも、彼があなたに対して隠していることは、まだ見えていません。',
  renraku_teishi:  'でも、彼の沈黙の本当の理由は、まだ見えていません。',
  aimai_teitai:    'でも、この関係を曖昧にしている「彼の事情」は、まだ見えていません。',
  fukuen_shuchaku: 'でも、あなたの中で終わっていない「本当のもの」は、まだ見えていません。',
};

// ── ミニ鑑定結果テキスト ──

function buildResultText(type: DiagnosisType, q3: number): string {
  const results: Record<DiagnosisType, string> = {
    kimochi_maigo: `✨ 凛の瞳が紫に変わりました。

今のあなたは「彼の気持ち迷子型」です。

気持ちがないのか、あるけれど踏み込めないのか。その境目が見えなくなっています。

この恋が止まりやすいのは、彼の表の態度と裏の本音に温度差があるからかもしれません。

まず見るべきは、言葉より「近づき方」です。`,

    renraku_teishi: `🌙 凛の左目の下の傷が疼いています。

今のあなたは「連絡停止不安型」です。

返事が来ないことそのものより、その意味がわからないことがいちばん苦しい状態です。

この恋が止まりやすいのは、沈黙を拒絶だと受け取りやすくなっているからかもしれません。

まず見るべきは、返事の有無より途切れ方の癖です。`,

    aimai_teitai: `🐾 凛の耳がぴくっと動きました。

今のあなたは「曖昧関係停滞型」です。

会える。話せる。でも、深まらない。切れていないのに、進まないまま時間だけが過ぎていく。

この恋が止まりやすいのは、関係の形が曖昧なまま安心だけ続いているからかもしれません。

まず見るべきは、好意の有無より相手が責任を持つ気配があるかどうかです。`,

    fukuen_shuchaku: `🌙 凛の尻尾が今日は重いです。

今のあなたは「復縁執着型」です。

終わったはずなのに、気持ちだけがまだ終われていない。

この恋が止まりやすいのは、相手への未練だけでなく、自分の中で未完了の何かが残っているからかもしれません。

まず見るべきは、戻れるかどうかより何がまだ終わっていないのかです。`,
  };

  const custom = Q3_LINES[type][q3] || '';
  const unseen = UNSEEN[type];

  return `${results[type]}

${custom}

${unseen}`;
}

// ── CTA ──

function buildCtaMessage(): Message {
  return textWithQR(
    `このまま月の便りを受け取りながら、少しずつ見え方を整えていくこともできます。

もし今、彼の気持ちとこの恋の現在地、そして止まっている理由まではっきり知りたいなら 🌙`,
    [
      { label: '月の便りを待つ', text: '月の便りを待つ' },
      { label: '凛に見てもらう', text: '凛に見てもらう' },
    ],
  );
}

// ── メイン処理 ──

export interface DiagnosisBotResult {
  messages: Message[];
  diagnosisType?: DiagnosisType;
  consumed: boolean;
}

export async function handleDiagnosisMessage(
  db: D1Database,
  friendId: string,
  incomingText: string,
): Promise<DiagnosisBotResult> {
  const row = await db.prepare('SELECT metadata FROM friends WHERE id = ?')
    .bind(friendId).first<{ metadata: string }>();
  const metadata = JSON.parse(row?.metadata || '{}') as Record<string, unknown>;
  const state = metadata.diagnosis_state as DiagnosisState | undefined;

  if (incomingText === '湖') {
    metadata.diagnosis_state = { step: 'q1' } as DiagnosisState;
    await updateMetadata(db, friendId, metadata);
    return { messages: [buildQ1()], consumed: true };
  }

  if (incomingText === '月の便りを待つ') {
    return {
      messages: [{ type: 'text', text: `わかりました 🌙\n\n明日から少しずつ、凛のこと、この湖のこと、お話しさせてください。急がなくて大丈夫です。ゆっくり、一歩ずつ。` } as Message],
      consumed: true,
    };
  }

  if (incomingText === '凛に見てもらう') {
    return {
      messages: [{ type: 'text', text: `🪞 彼の気持ちと、この恋の現在地がわかる関係整理鑑定。

凛のオリジナル9枚リーディング「鏡の湖スプレッド」で、彼の気持ちの温度感、この恋が止まっている理由、この先2週間で何をして何を見るかまで読み解きます。

鑑定書は5,000文字。あなた一人のために、すべて手作りで綴ります ✨

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
