-- ============================================================
-- v3-day0-survey-flex.sql
-- Day0直後アンケートFlex Message を friend_add scenario に追加
-- ============================================================
-- 作成日: 2026-04-25
-- 設計正本: 占い事業/instagram/11_n8n-D5-Day0アンケートFlex設計.md
-- 設計補助: 占い事業/instagram/02_LINE誘導動線設計.md
--
-- 目的:
--   friend_add (8ee12685-8ffa-491d-8bed-0c788a02307f) シナリオに
--   Day0テキスト直後のアンケートFlexを挿入する。
--   3択ボタン: Instagram bio / Instagram Stories/ハイライト / その他
--   postback data は webhook.ts → n8n WF6 で Sheets に流入元を記録する。
--
-- 設計判断:
--   - scenario_steps は UNIQUE(scenario_id, step_order) 制約あり、step_order は INTEGER。
--   - 既存 step_order: 0(Day0/text/即時) / 1(Day1/text/1440分後) / 3〜7(Day3〜7)。step_order=2 は空席。
--   - 「Day0直後」を実現するため、新規アンケートFlex を step_order=1 / delay_minutes=1
--     （Day0配信1分後）として INSERT する。
--   - 衝突回避のため、先に既存 step_order=1 (Day1) を空席の step_order=2 に UPDATE してから新規行を INSERT。
--   - 既存 friend_scenarios は current_step_order=6 の active 2件のみ。current_step_order > 2
--     なので step_order=1/2 への変更は既存friendの配信に影響しない（次の探索は step_order > 6 = step_order=7）。
--   - 新規 friend_add は: Day0(0/0min) → アンケートFlex(1/1min) → Day1(2/1440min) → Day3(3/4320min) ...
--     と配信される。Day1 の delay_minutes は前stepの配信時刻基準で計算されるため、
--     Day0からの相対的な配信タイミングは概ね維持される（厳密には1分のズレ + jitter のみ）。
--
-- ロールバック:
--   ROLLBACK_v3-day0-survey-flex.sql を別途用意（本ファイルでは未生成）。
--   - 新規 step_order=1 (flex) を DELETE
--   - 既存 Day1 (step_order=2) を step_order=1 に戻す
-- ============================================================

-- Step 1: 既存 Day1 (step_order=1) を step_order=2 / delay_minutes=1439 へ移動
--   合計1440分（=1日）を維持しつつ、新規Flex(delay=1分) との累積で Day0+1日を保つ
UPDATE scenario_steps
SET step_order = 2,
    delay_minutes = 1439
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f'
  AND step_order = 1;

-- Step 2: アンケートFlex を step_order=1 / delay_minutes=1 で INSERT
INSERT INTO scenario_steps (
  id,
  scenario_id,
  step_order,
  delay_minutes,
  message_type,
  message_content,
  created_at
) VALUES (
  'a1b2c3d4-e5f6-4789-a012-3456789abcde',
  '8ee12685-8ffa-491d-8bed-0c788a02307f',
  1,
  1,
  'flex',
  '{"type":"bubble","size":"mega","body":{"type":"box","layout":"vertical","spacing":"md","paddingAll":"20px","contents":[{"type":"text","text":"ここまで来てくれたのは、","size":"sm","color":"#6B6B6B","wrap":true},{"type":"text","text":"どこから、ですか。","size":"lg","weight":"bold","color":"#2A2A2A","wrap":true,"margin":"none"},{"type":"separator","margin":"lg","color":"#E8E4DC"},{"type":"text","text":"もしよければ、教えてください。\n答えなくても、次の便りは届きます。","size":"xs","color":"#8A8A8A","wrap":true,"margin":"lg"}]},"footer":{"type":"box","layout":"vertical","spacing":"sm","paddingAll":"16px","contents":[{"type":"button","style":"secondary","height":"sm","action":{"type":"postback","label":"Instagram bio","data":"src=ig_bio","displayText":"Instagram bio から来ました"}},{"type":"button","style":"secondary","height":"sm","action":{"type":"postback","label":"Instagram Stories/ハイライト","data":"src=ig_highlight","displayText":"Instagram Stories から来ました"}},{"type":"button","style":"secondary","height":"sm","action":{"type":"postback","label":"その他","data":"src=other","displayText":"その他から来ました"}}]},"styles":{"body":{"backgroundColor":"#FBFAF6"},"footer":{"backgroundColor":"#FBFAF6"}}}',
  strftime('%Y-%m-%dT%H:%M:%f', 'now', '+9 hours')
);
