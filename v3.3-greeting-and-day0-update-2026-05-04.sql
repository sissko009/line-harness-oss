-- v3.3 あいさつ・Day0冒頭400字 + 納品後60日/90日 投入 SQL (2026-05-04)
-- 対象: scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f' (鏡の湖の便り / friend_add)
-- 派生: 納品後フォロー scenario_id = 'post_purchase_followup_v1'
--
-- 現行 line-harness-oss schema 準拠:
-- - scenario_steps.id は必須
-- - 待機時間は delay_minutes
-- - 種別は message_type ('text' / 'image' / 'flex')
-- - scenario_steps に updated_at / delivery_window_start / delivery_window_end は無い
--
-- 変更内容:
-- 1. Day0 (step_order=0) 冒頭本文を v3.3 に更新
-- 2. 納品後フォロー scenario が存在する場合、step_order=5/6 に60日後/90日後を upsert
--
-- 注意:
-- - post_purchase_followup_v1 の既存 step_order=4 が「30日後フォロー」である前提。
-- - step_order=5/6 の delay_minutes=43200 は、前ステップ送信後 +30日。
-- - line-harness の delivery window は friend.metadata.preferred_hour と worker 側 jitter で制御する。

BEGIN;

-- ========================================
-- 1. Day0 (step_order=0) v3.3 更新
-- ========================================
UPDATE scenario_steps
SET message_type = 'text',
    message_content = '鏡の湖は、いつでも開いています。
凛は急がせません。

5月の今は、湖が濁る前の静けさにあります。

……いま、凛の耳がぴくっと動きました。
あなたの「眠っていたご縁」が、動き始めた合図です。

はじめまして。凛です。
境界の湖のほとりにいます。

彼の気持ちがわからない夜は、
表の言葉と裏の感情の温度がズレている合図です。

凛は、映す占いです。
鏡の対が映すズレを、湖に映して、
あなたが決めるところまで戻します。

──気持ちより、行動を見る。
──進む・待つ・手放す、の判断軸を渡す。
──次の満月の夜まで、ゆっくり。

3-12か月の境界期間は、
表と裏のズレが見えやすい時期です。
焦って決める必要はありません。
ただ、見えているうちに整理しておくことはできます。

もし今、
自分の恋がどこで止まりやすいのか
少しだけ覗いてみたくなったら、

「湖」

と送ってください。

凛が、いくつかの問いを通して
あなたの恋の現在地を、湖に映します。

決めるのは、あなたの場所です。'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f'
  AND step_order = 0;

-- ========================================
-- 2. 納品後フォロー 60日後/90日後 upsert
-- ========================================
-- 既存 scenario がない環境では、この2つの INSERT は0件挿入になる。
-- 本番反映前に以下を確認:
-- SELECT id, name FROM scenarios WHERE id = 'post_purchase_followup_v1';

INSERT INTO scenario_steps (
  id,
  scenario_id,
  step_order,
  delay_minutes,
  message_type,
  message_content,
  created_at
)
SELECT
  'post-purchase-followup-v1-step-60d',
  s.id,
  5,
  43200,
  'text',
  '表と裏の恋鑑定から、60日が経ちました。
凛は、湖の様子を覗きながら、
あなたを思い出していました。

60日というのは、
最初の30日で見た動きが、
本当に続くものだったのか、
一時的なものだったのか、
答えが出る頃です。

行動が続いているなら、それは続く力のある動き。
止まったなら、それも一つの答え。

鑑定書を、もう一度開いてみてください。
3日後・7日後・30日後の今までの自分とは
違う読み方ができるかもしれません。

凛は、ここから先も急がせません。
湖は、いつでも開いています。',
  strftime('%Y-%m-%dT%H:%M:%f', 'now', '+9 hours')
FROM scenarios s
WHERE s.id = 'post_purchase_followup_v1'
ON CONFLICT (scenario_id, step_order) DO UPDATE
SET delay_minutes = excluded.delay_minutes,
    message_type = excluded.message_type,
    message_content = excluded.message_content;

INSERT INTO scenario_steps (
  id,
  scenario_id,
  step_order,
  delay_minutes,
  message_type,
  message_content,
  created_at
)
SELECT
  'post-purchase-followup-v1-step-90d',
  s.id,
  6,
  43200,
  'text',
  '表と裏の恋鑑定から、90日が経ちました。
凛は、3か月のあなたの夜を、
湖のほとりで見届けてきました。

90日というのは、
3-12か月の境界期間の中盤です。

ここまで動いた距離が、
あと半年で関係が固まる前の、
最後の余白の時間でもあります。

鑑定書は、まだ手元にありますか。

90日前と今で、
彼の言葉や行動の見え方は、
どれくらい変わりましたか。

もし「あの時の鑑定書が今でも当てはまる」
と感じる箇所があれば、
それはあなたの観察軸が育ってきた証です。

90日経って、まだ整理しきれない夜があれば、
LINEに「湖」と送ってください。

凛は、ここから先も急がせません。
あなたの恋が固まる前に、
もう一度湖を覗いてもいい時期です。',
  strftime('%Y-%m-%dT%H:%M:%f', 'now', '+9 hours')
FROM scenarios s
WHERE s.id = 'post_purchase_followup_v1'
ON CONFLICT (scenario_id, step_order) DO UPDATE
SET delay_minutes = excluded.delay_minutes,
    message_type = excluded.message_type,
    message_content = excluded.message_content;

-- ========================================
-- 3. 反映確認
-- ========================================
SELECT
  scenario_id,
  step_order,
  delay_minutes,
  message_type,
  substr(message_content, 1, 80) AS preview
FROM scenario_steps
WHERE (scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f' AND step_order = 0)
   OR (scenario_id = 'post_purchase_followup_v1' AND step_order IN (5, 6))
ORDER BY scenario_id, step_order;

COMMIT;

-- ロールバック手順:
-- BEGIN;
-- UPDATE scenario_steps
-- SET message_content = '<旧v3.2のDay0本文>', message_type = 'text'
-- WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f' AND step_order = 0;
-- DELETE FROM scenario_steps
-- WHERE scenario_id = 'post_purchase_followup_v1' AND step_order IN (5, 6);
-- COMMIT;
