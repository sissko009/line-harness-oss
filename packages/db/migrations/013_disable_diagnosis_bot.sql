-- ============================================================
-- 013: 無料診断Bot 廃止 — auto_replies 無効化 (2026-05-25)
-- ============================================================
-- 背景: LINE は「教育・導線・宣伝」のみに絞る方針変更（2026-05-24 こっさん指示）。
-- 「湖」キーワードで起動する無料診断Bot（4タイプ診断）を停止する。
-- diagnosis-bot.ts は DIAGNOSIS_BOT_ENABLED=false で既にコード側は無効化済み。
-- ここでは auto_replies テーブル上の関連キーワードトリガーを is_active=0 にする。
-- DELETE ではなく UPDATE（安全策・履歴保持）。
-- ============================================================

-- 1. 「湖」キーワード（ミニ鑑定導入 Flex メッセージ）
UPDATE auto_replies SET is_active = 0 WHERE keyword = '湖' AND is_active = 1;

-- 2. 診断Bot CTA の QuickReply キーワード
UPDATE auto_replies SET is_active = 0 WHERE keyword = '凛に見てもらう' AND is_active = 1;
UPDATE auto_replies SET is_active = 0 WHERE keyword = '月の便りを待つ' AND is_active = 1;

-- 3. 悩みカテゴリ選択ボタン（tmp_lake.sql の Flex 内 QuickReply が発行するテキスト）
UPDATE auto_replies SET is_active = 0 WHERE keyword = '悩み_迷い' AND is_active = 1;
UPDATE auto_replies SET is_active = 0 WHERE keyword = '悩み_執着' AND is_active = 1;
UPDATE auto_replies SET is_active = 0 WHERE keyword = '悩み_復縁' AND is_active = 1;
UPDATE auto_replies SET is_active = 0 WHERE keyword = '悩み_停滞' AND is_active = 1;

-- 確認クエリ（適用後に手動実行する想定）:
-- SELECT id, keyword, is_active FROM auto_replies
-- WHERE keyword IN ('湖', '凛に見てもらう', '月の便りを待つ', '悩み_迷い', '悩み_執着', '悩み_復縁', '悩み_停滞');
