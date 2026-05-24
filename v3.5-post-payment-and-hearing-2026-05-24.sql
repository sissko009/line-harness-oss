-- v3.5 受け口改善: 決済直後納品時刻明示 + 本命購入後ヒアリング (2026-05-24)
--
-- 目的:
--   1. 鑑定購入直後（決済完了→鑑定書生成中）に「納品時刻」を明示する単発メッセージ
--   2. ¥4,980本命購入直後に、ヒアリング5項目を1メッセージで聞く
--
-- 設計参照:
--   - 占い事業/LINE/2026-05-24_納品時刻明示メッセージ設計.md
--   - 占い事業/LINE/2026-05-24_鑑定購入後ヒアリング5項目設計.md
--   - 占い事業/LINE/2026-05-24_LINE受け口改善設計_業務キット流.md
--
-- トリガー方式:
--   - trigger_type='manual' でシナリオ作成
--   - n8n の MOSH 決済 webhook が POST /api/scenarios/:id/enroll/:friendId を呼んで友だちを enroll
--   - enroll 時点で step_order=1（delay=0）が即時配信される
--
-- 反映前にやること:
--   - <RIN_ACCOUNT_ID> を本番の rin LINE 公式アカウント ID に置換
--   - D1 dump backup を取得（DEPLOY-NOTES-2026-05-10.md に手順あり）
--
-- ⚠️ 重要: 置換忘れガード
--   下の SELECT で 0 件以外が返ったら、置換漏れで実行を中止する。
--   wrangler d1 execute --command="SELECT id FROM line_accounts WHERE id = '<RIN_ACCOUNT_ID>'"
--   ↑ ヒットしたら placeholder のまま実行してリテラル値が入る危険があるので、置換してから再実行。

BEGIN;

-- Placeholder ガード: line_accounts に '<RIN_ACCOUNT_ID>' というIDが残っていれば、ありえないが念のため検出
-- （SQLite では BEGIN内で RAISE する手段が限られるため、ここでは存在チェック SELECT のみ）
SELECT
  CASE WHEN EXISTS (SELECT 1 FROM line_accounts WHERE id = '<RIN_ACCOUNT_ID>')
    THEN 'WARN: <RIN_ACCOUNT_ID> literal exists in line_accounts — replace before running'
    ELSE 'OK: no literal placeholder'
  END AS placeholder_check;

-- ============================================================
-- 1. ミニ鑑定¥480 決済後 納品時刻明示シナリオ
-- ============================================================

INSERT INTO scenarios (id, name, description, trigger_type, is_active, line_account_id)
VALUES (
  'post_payment_pending_mini_v1',
  'ミニ鑑定¥480 決済後 納品時刻明示',
  '¥480 ミニ鑑定 決済完了直後に納品時刻（24時間以内）を明示する単発メッセージ。n8n決済webhookから手動enrollで起動。',
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
おおむね24時間以内にお届けします。

夜のお申込みなら、翌日の夜までに。
朝のお申込みなら、その日の夜までに。

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
-- 2. 本命鑑定¥4,980 決済後 納品時刻明示 + ヒアリング5項目シナリオ
-- ============================================================
-- 設計判断: 複雑な postback 連鎖を避け、1メッセージで5項目まとめて聞く（業務キット流 1メッセージ1目的）
-- 回答は自由テキストで返信される。metadata 保存は line-ops 側で別途実装（n8n受信→friend metadata更新）

INSERT INTO scenarios (id, name, description, trigger_type, is_active, line_account_id)
VALUES (
  'post_payment_pending_main_v1',
  '本命鑑定¥4,980 決済後 納品時刻明示+ヒアリング',
  '¥4,980 表と裏の恋鑑定 決済完了直後に納品時刻（48時間以内）明示 + ヒアリング5項目を2通で配信。n8n決済webhookから手動enrollで起動。',
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

-- step 1: 御礼 + 納品時刻明示
INSERT INTO scenario_steps (id, scenario_id, step_order, delay_minutes, message_type, message_content)
VALUES (
  'post-payment-pending-main-v1-step-1',
  'post_payment_pending_main_v1',
  1,
  0,
  'text',
  '表と裏の恋鑑定のお申込み、ありがとうございます。

鑑定書は、おおむね48時間以内にPDFでお届けします。

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

-- step 2: ヒアリング5項目（1メッセージ・1分後配信）
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

1. お名前または呼び方（イニシャル可）
2. 彼の呼び方（イニシャル可）
3. 関係期間（例: 1年半）
4. いま一番苦しいこと（ひとことで）
5. 鑑定書の希望タイミング（今夜 / 明日以降 / 急いで読みたい）

それぞれ改行で、まとめて送ってもらえると湖がよく映ります。
書ける範囲で構いません。
答えてもらえなくても、鑑定書は届きます。

凛'
)
ON CONFLICT (scenario_id, step_order) DO UPDATE
SET message_type = excluded.message_type,
    message_content = excluded.message_content;

-- ============================================================
-- 3. 旧無料診断Bot トリガーのクリーンアップ (2026-05-24)
-- ============================================================
-- 「湖」「凛に見てもらう」「月の便りを待つ」等の旧QRトリガーが auto_replies テーブルに
-- 残っている場合は無効化する。テーブル名・カラム名は schema を確認の上 line-ops が調整。
-- 安全のため DELETE ではなく is_active=0 (deactivate) のみ。
-- 該当カラムが無いスキーマでも実行できるよう個別 UPDATE は line-ops が確認後に追加する形にする。

-- 確認クエリ（事前に手動で実行する想定）:
--   SELECT * FROM auto_replies WHERE keyword IN ('湖', '凛に見てもらう', '月の便りを待つ');
-- ヒットしたレコードがあれば次を実行:
--   UPDATE auto_replies SET is_active = 0 WHERE keyword IN ('湖', '凛に見てもらう', '月の便りを待つ');
-- ※ auto_replies テーブルやカラム名が異なる場合は schema.sql を確認

-- ============================================================
-- 4. Verification preview
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
