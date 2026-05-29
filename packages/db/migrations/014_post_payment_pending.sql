-- Migration 014: 購入直後 納品時刻明示メッセージ用シナリオ (2026-05-25)
--
-- 目的:
--   1. ¥480ミニ鑑定 購入直後に「3〜5日以内にお届け」を明示する単発メッセージ
--   2. ¥4,980本命鑑定 購入直後に納品時刻明示 + ヒアリング5項目（2通構成）
--
-- トリガー方式:
--   trigger_type='manual' — n8n の MOSH 決済 webhook が
--   POST /api/scenarios/:id/enroll/:friendId を呼んで友だちを enroll。
--   enroll 時点で step_order=1（delay=0）が即時配信される。
--
-- 反映前にやること:
--   <RIN_ACCOUNT_ID> を本番の rin LINE 公式アカウント ID に置換
--
-- 実行:
--   wrangler d1 execute line-crm --file=packages/db/migrations/014_post_payment_pending.sql --remote

BEGIN;

-- ============================================================
-- 1. ミニ鑑定 ¥480 購入直後 納品時刻明示
-- ============================================================

INSERT INTO scenarios (id, name, description, trigger_type, is_active, line_account_id)
VALUES (
  'post_payment_pending_mini_v1',
  '¥480ミニ鑑定 購入直後 納品時刻明示',
  '¥480 ミニ鑑定 購入直後に納品目安（3〜5日以内）を明示する単発メッセージ。n8n決済webhookから手動enrollで起動。',
  'manual',
  1,
  '<RIN_ACCOUNT_ID>'
)
ON CONFLICT (id) DO UPDATE
SET name = excluded.name,
    description = excluded.description,
    trigger_type = excluded.trigger_type,
    is_active = excluded.is_active,
    line_account_id = excluded.line_account_id;

INSERT INTO scenario_steps (id, scenario_id, step_order, delay_minutes, message_type, message_content)
VALUES (
  'post-payment-pending-mini-v1-step-1',
  'post_payment_pending_mini_v1',
  1,
  0,
  'text',
  '鏡の湖ミニ鑑定のお申込み、ありがとうございます。

鏡の湖が、いまの現在地を映すまで、
ご入金確認後、3〜5日以内を目安にお届けします。

凛は急がせません。
今夜は、読むだけで終えても大丈夫です。

鑑定書が届く前に、もし思い出したことがあれば、
このトークでひとことだけ送っておいてもらえると、
湖がより静かに映ります。'
)
ON CONFLICT (scenario_id, step_order) DO UPDATE
SET message_type = excluded.message_type,
    message_content = excluded.message_content;

-- ============================================================
-- 2. 本命鑑定 ¥4,980 購入直後 納品時刻明示 + ヒアリング予告
-- ============================================================

INSERT INTO scenarios (id, name, description, trigger_type, is_active, line_account_id)
VALUES (
  'post_payment_pending_main_v1',
  '¥4,980本命鑑定 購入直後 納品時刻明示+ヒアリング予告',
  '¥4,980 表と裏の恋鑑定 購入直後に納品目安（3〜5日以内）明示 + ヒアリング5項目を2通で配信。n8n決済webhookから手動enrollで起動。',
  'manual',
  1,
  '<RIN_ACCOUNT_ID>'
)
ON CONFLICT (id) DO UPDATE
SET name = excluded.name,
    description = excluded.description,
    trigger_type = excluded.trigger_type,
    is_active = excluded.is_active,
    line_account_id = excluded.line_account_id;

-- step 1: 御礼 + 納品時刻明示 + ヒアリング予告
INSERT INTO scenario_steps (id, scenario_id, step_order, delay_minutes, message_type, message_content)
VALUES (
  'post-payment-pending-main-v1-step-1',
  'post_payment_pending_main_v1',
  1,
  0,
  'text',
  '表と裏の恋鑑定のお申込み、ありがとうございます。

鑑定書は、ご入金確認後3〜5日以内を目安にPDFでお届けします。

凛は、彼の気持ちを当てるのではなく、
気持ちより、行動・約束の置き方を見ます。
だから、表と裏の対のズレを、湖がゆっくり映すまで
少しお時間をいただいています。

このあと、湖がよく映るために
5つだけ確認させてください。
書ける範囲で大丈夫です。
答えてもらえなくても、鑑定書はそのまま届きます。'
)
ON CONFLICT (scenario_id, step_order) DO UPDATE
SET message_type = excluded.message_type,
    message_content = excluded.message_content;

-- step 2: ヒアリング5項目（1分後配信）
INSERT INTO scenario_steps (id, scenario_id, step_order, delay_minutes, message_type, message_content)
VALUES (
  'post-payment-pending-main-v1-step-2',
  'post_payment_pending_main_v1',
  2,
  1,
  'text',
  '鏡の湖が、いまの現在地を映すために、
5つだけ聞かせてください。
急がなくて大丈夫です。

1. お名前（呼び方）
鑑定書の中で、あなたを何とお呼びすればよいですか。イニシャル可、ニックネーム可。

2. 彼の呼び方
鑑定書の中で、彼を何とお呼びすればよいですか。イニシャル（例: Sさん）でも構いません。

3. 関係期間
彼との関係は、どれくらい続いていますか。（3ヶ月未満/3〜6ヶ月/6〜12ヶ月/1〜2年/2〜3年/3年以上）

4. いま一番苦しいこと
鏡の湖に最初に映したいのは、どんなことですか。ひとことで構いません。

5. 希望タイミング
鑑定書を、いつ受け取るのが心地よいですか。（今夜・読むだけで終えたい/明日以降・落ち着いて読みたい/できるだけ早く読みたい）'
)
ON CONFLICT (scenario_id, step_order) DO UPDATE
SET message_type = excluded.message_type,
    message_content = excluded.message_content;

-- ============================================================
-- Verification preview
-- ============================================================

SELECT
  s.id AS scenario_id,
  s.name,
  s.trigger_type,
  s.is_active,
  ss.step_order,
  ss.delay_minutes,
  substr(ss.message_content, 1, 60) AS preview
FROM scenarios s
LEFT JOIN scenario_steps ss ON ss.scenario_id = s.id
WHERE s.id IN ('post_payment_pending_mini_v1', 'post_payment_pending_main_v1')
ORDER BY s.id, ss.step_order;

COMMIT;
