/**
 * エスカレーション検出
 *
 * 受信メッセージから「自動応答で完結させない」判断項目を検出し、
 * 凛事業の特性に合わせて4段階の温度で扱う。
 *
 * 設計参照: 占い事業/LINE/2026-05-24_クレーム返金体調エスカレーション設計.md
 *
 * 2026-05-24 v2: 凛のターゲット層（恋愛で詰まる女性）の日常表現と衝突しないよう、
 * キーワード辞書を厳密化。誤検知で配信全停止する事故を防ぐ。
 *   - safety は「明確な自殺示唆」のみに絞る（医療相談は medical_consult へ）
 *   - claim は「明確に運営者へ向けた語」のみに絞る（感情語「嘘/ひどい/最悪」は除外）
 *   - high_anxiety カテゴリは廃止（単独で配信止める根拠が弱い）
 *   - medical_consult は新設（病院/薬/主治医/精神科/心療内科/うつ/パニック）
 *     → 自動応答は止めず、metadata フラグ + 日次ダイジェスト通知のみ
 */

import type { Message } from '@line-crm/line-sdk';

export type EscalationCategory =
  | 'safety'           // 明確な自殺示唆・自傷 — 即時 @here 通知 + 配信停止 + 緊急窓口案内
  | 'refund'           // 返金・キャンセル — 自動応答停止 + 通常通知
  | 'claim'            // 明確なクレーム（運営者向け）— 自動応答停止 + 通常通知
  | 'medical_consult'; // 医療・体調相談 — 自動応答は止めない・metadata フラグのみ

const ESCALATION_KEYWORDS: Record<EscalationCategory, string[]> = {
  // safety: 明確な自殺示唆ワードのみ。日常会話で出にくい強キーワードに限定する。
  // 「死ぬ」は「死ぬほど好き」等の慣用句で誤爆するため除外。「死にたい」など意志を伴う表現のみ採る。
  safety: [
    '死にたい',
    '消えたい',
    'いなくなりたい',
    '自殺',
    'リスカ',
    'リストカット',
    'OD',
    '自傷',
  ],

  // refund: 返金・契約に関する明確な語のみ。
  refund: [
    '返金',
    'キャンセル',
    '払い戻し',
    '解約',
    'クーリングオフ',
    '消費者センター',
    '騙された',
    '詐欺',
  ],

  // claim: 明確に運営者へ向けた語のみ。感情語（嘘/ひどい/最悪）は恋愛相談で日常使用されるため除外。
  claim: [
    'クレーム',
    '訴える',
    '弁護士',
    '通報',
    '内容証明',
    '消費者庁',
  ],

  // medical_consult: 医療・体調相談。自動応答は止めず metadata フラグのみ。
  // 「彼が病院に行ってて会えない」「お薬手帳が」等で発火するが、これは "@here なし・配信止めない"
  // で誤検知の影響を最小化する。
  medical_consult: [
    '病院',
    '主治医',
    '精神科',
    '心療内科',
    '救急',
    'うつ病',
    'パニック障害',
  ],
};

/**
 * 受信テキストからエスカレーションカテゴリを判定する。
 * 優先順位は safety > refund > claim > medical_consult。
 * 該当なしなら null。
 */
export function detectEscalation(text: string): EscalationCategory | null {
  const order: EscalationCategory[] = ['safety', 'refund', 'claim', 'medical_consult'];
  for (const cat of order) {
    if (ESCALATION_KEYWORDS[cat].some(kw => text.includes(kw))) {
      return cat;
    }
  }
  return null;
}

/**
 * カテゴリ別の最小応答メッセージ。
 *
 * - safety: 119/110/救急/身近な人への即時連絡を最優先で案内。公的窓口は補助。
 *   LINE 待機を誘発する文面は避ける。
 * - refund/claim: 人が確認することの意思表示のみ。
 * - medical_consult: ユーザー側に応答を返さない（後段の通常応答に流す）
 *   → 呼び出し側で `category === 'medical_consult'` 時は応答スキップする運用想定
 */
export function buildAcknowledgeMessage(cat: EscalationCategory): Message {
  switch (cat) {
    case 'safety':
      return {
        type: 'text',
        text: `メッセージありがとうございます。
凛がこちらで受け取りました。

いま自分を傷つけそう、または今夜が危ないと感じる場合は、
このLINEの返事を待たずに、
119（救急）/ 110（警察）/ 近くの救急外来、
または身近な人へ連絡してください。

ひとりで抱えるのが苦しい夜は、次の窓口も使えます。
・よりそいホットライン: 0120-279-338（24時間・無料）
・こころの健康相談統一ダイヤル: 0570-064-556
・いのちの電話: 0570-783-556

凛は医療や緊急対応はできません。
でも、ここに置いてくれた声は確認します。

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

    case 'medical_consult':
      // 応答せず後段の通常処理に流す（呼び出し側で skip 判定）
      return {
        type: 'text',
        text: '',
      } as Message;
  }
}

/**
 * カテゴリ別の挙動指示。webhook ハンドラがこれを見て分岐する。
 */
export interface EscalationBehavior {
  /** ユーザーに最小応答を返すか */
  replyToUser: boolean;
  /** 後段の自動応答・ステップ配信を止めるか（friend metadata に escalation_pending=true 記録 → 配信側で見る） */
  pauseDelivery: boolean;
  /** Discord 通知の温度（mention付き / 通常） */
  notifyLevel: 'urgent' | 'normal' | 'digest';
}

export function getEscalationBehavior(cat: EscalationCategory): EscalationBehavior {
  switch (cat) {
    case 'safety':
      return { replyToUser: true, pauseDelivery: true, notifyLevel: 'urgent' };
    case 'refund':
    case 'claim':
      return { replyToUser: true, pauseDelivery: true, notifyLevel: 'normal' };
    case 'medical_consult':
      return { replyToUser: false, pauseDelivery: false, notifyLevel: 'digest' };
  }
}

/**
 * カテゴリの日本語ラベル（ログ・通知用）。
 */
export const ESCALATION_LABELS: Record<EscalationCategory, string> = {
  safety: '体調・安全相談',
  refund: '返金・キャンセル',
  claim: 'クレーム',
  medical_consult: '医療・体調相談',
};
