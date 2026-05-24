/**
 * エスカレーション検出
 *
 * 返金・クレーム・体調・安全相談・強い不安の受信を検知し、自動応答を停止する。
 *
 * 業務キット§7「クレーム初動 / 返金相談 / 体調・安全相談」は自動返信で完結させない原則を、
 * 凛LINEに適用する。特に safety カテゴリは凛事業の特性上、最優先で潰すべき受け口リスク。
 *
 * 設計参照: 占い事業/LINE/2026-05-24_クレーム返金体調エスカレーション設計.md
 */

import type { Message } from '@line-crm/line-sdk';

export type EscalationCategory =
  | 'safety'        // 体調・安全相談（最優先）
  | 'refund'        // 返金・キャンセル
  | 'claim'         // クレーム
  | 'high_anxiety'; // 強い不安・依存

const ESCALATION_KEYWORDS: Record<EscalationCategory, string[]> = {
  safety: [
    '死にたい', '消えたい', 'いなくなりたい', '死ぬ', '自殺',
    'リスカ', 'リストカット', 'OD',
    '病院', '薬', '主治医', '精神科', '心療内科', '救急',
    'うつ', 'パニック',
  ],
  refund: [
    '返金', 'キャンセル', '払い戻し', '解約',
    'クーリングオフ', '消費者センター',
    '騙された', '詐欺',
  ],
  claim: [
    'クレーム', '嘘', 'ひどい', '最悪',
    '訴える', '弁護士', '通報',
  ],
  high_anxiety: [
    'もう無理', '限界', '眠れない', '食べられない',
  ],
};

/**
 * 受信テキストからエスカレーションカテゴリを判定する。
 * 優先順位は safety > refund > claim > high_anxiety。
 * 該当なしなら null。
 *
 * 注: 部分一致。誤検知を避けるため short/曖昧キーワード（「助けて」単独等）は除外している。
 */
export function detectEscalation(text: string): EscalationCategory | null {
  const order: EscalationCategory[] = ['safety', 'refund', 'claim', 'high_anxiety'];
  for (const cat of order) {
    if (ESCALATION_KEYWORDS[cat].some(kw => text.includes(kw))) {
      return cat;
    }
  }
  return null;
}

/**
 * カテゴリ別の最小応答メッセージ。
 * 凛の口調を保ちつつ、AI自動応答で完結させない意思を表す。
 * safety は必ず公的窓口を案内する。
 */
export function buildAcknowledgeMessage(cat: EscalationCategory): Message {
  switch (cat) {
    case 'safety':
      return {
        type: 'text',
        text: `メッセージありがとうございます。
凛がこちらで受け取りました。

いま、ひとりで抱えているのが苦しいなら、
よかったら次の窓口も覗いてみてください。

・よりそいホットライン: 0120-279-338（24時間・無料・通話料なし）
・いのちの電話: 0570-783-556
・こころの健康相談統一ダイヤル: 0570-064-556

凛も、ここで受け取っています。
すぐに返事ができないこともありますが、必ず読みます。

凛`,
      } as Message;

    case 'refund':
    case 'claim':
      return {
        type: 'text',
        text: `ご連絡ありがとうございます。
内容を確認して、凛から直接ご返信します。

少しお時間をいただきますが、必ずお返事します。

凛`,
      } as Message;

    case 'high_anxiety':
      return {
        type: 'text',
        text: `メッセージ受け取りました。
凛が読んでいます。

返事まで少し時間がかかることがあります。
それでも、ここに送ったことは届いています。

凛`,
      } as Message;
  }
}

/**
 * カテゴリの日本語ラベル（ログ・通知用）。
 */
export const ESCALATION_LABELS: Record<EscalationCategory, string> = {
  safety: '体調・安全相談',
  refund: '返金・キャンセル',
  claim: 'クレーム',
  high_anxiety: '強い不安・依存',
};
