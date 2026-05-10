-- v3.4 46_DB compliance reflection SQL (2026-05-10)
-- Target scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f' (friend_add)
-- Post-purchase scenario_id = 'post_purchase_followup_v1'
--
-- Scope:
-- - No schema changes.
-- - Update friend_add Day0/Day1/Day3/Day4/Day5/Day6/Day7 to the 2026-05-06 LINE design docs.
-- - Upsert post-purchase immediate/3d/7d/30d/60d/90d follow-up steps when the scenario exists.
-- - Existing scenario absence yields 0 inserted post-purchase rows by design.
--
-- Safety:
-- - UPDATE predicates are restricted by scenario_id + step_order.
-- - INSERTs use SELECT FROM scenarios and ON CONFLICT (scenario_id, step_order) DO UPDATE.
-- - Run a D1 dump backup before remote execution. See DEPLOY-NOTES-2026-05-10.md.

BEGIN;

-- ========================================
-- 1. friend_add scenario: Day0-Day7
-- ========================================

UPDATE scenario_steps
SET message_type = 'text',
    message_content = '連絡は続いている。
嫌われている感じもしない。
でも、32歳を過ぎた今も、結婚の話だけが出ない。

そんな3-12か月の境界期間にいる人へ、ここを開いています。

凛が見るのは、彼の気持ちを当てることではありません。
気持ちより、行動・約束の置き方を見ます。
会う話が具体的になるか。
次の約束を彼の側から置くか。
「仕事が落ち着いたら」が、いつまでも先送りのままになっていないか。

鏡の湖は、表の言葉と実際の行動のズレを映します。
だから凛は、急いで答えを出しません。
進む・待つ・手放すを、自分で選べる軸を作るところから始めます。

今夜は、読むだけでOK。
まずは「自分がおかしいのかも」という責め方を、ここで止めましょう。

このあと受け取る「彼の気持ちタロット」も、
当てものではありません。
彼の表の言葉と、実際の行動のズレを
どこから見ればいいかを整えるためのものです。'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f'
  AND step_order = 0;

UPDATE scenario_steps
SET message_type = 'text',
    message_content = '32歳や33歳になると、
「まだ大丈夫」と「もう遅いかも」が同時に来る夜があります。

苦しいのは、彼の気持ちが見えないことだけではありません。
この関係をどう扱えばいいのか、自分で決めきれないことです。

鏡の湖は、彼の表の言葉と実際の行動のズレだけでなく、
あなた自身の我慢の置き方も映します。
だから凛は、まず「何が苦しいのか」を分けて見ます。'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f'
  AND step_order = 1;

UPDATE scenario_steps
SET message_type = 'text',
    message_content = 'やさしい。
でも進まない。
この時に必要なのは、単純な好意判定ではなく、関係の構造を見ることです。

たとえば、
- 会う提案がいつも曖昧
- 家族紹介の話だけ避ける
- 「仕事が落ち着いたら」が何度も繰り返される

こういう時、見てほしいのは気持ちより行動です。
凛は、行動・約束の置き方から現在地を整えます。'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f'
  AND step_order = 3;

UPDATE scenario_steps
SET message_type = 'text',
    message_content = '関係が止まりやすいのは、次のどれかが重なっている時です。

1. 好意はあるのに決断がない
2. 同棲しているのに将来の話が前に進まない
3. 婚活疲れで、自分から確認する気力が削れている
4. 夜のLINEだけで安心と不安を往復している

鏡の湖は、止まり方の種類を見分けるために使います。
止まり方が見えれば、進む・待つ・手放すのどこに近いかが見えてきます。'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f'
  AND step_order = 4;

UPDATE scenario_steps
SET message_type = 'text',
    message_content = 'ここまで読んで、
「彼の気持ちより、自分の判断材料がほしい」
と感じているなら、それは整えどきです。

表と裏の恋鑑定では、次の6点を返します。

- 彼の気持ちの温度感
- この恋の現在地
- 一番大きい停滞要因
- 今やらない方がいいこと
- 直近7日で見るサイン
- 30日判断の入口

気持ちより、行動・約束の置き方を見ます。
興味がある方は、関係整理の入口である「表と裏の恋鑑定（¥4,980）」の案内をご覧ください。

https://rin-tarot-web.vercel.app/?utm_source=line&utm_medium=step_day5'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f'
  AND step_order = 5;

UPDATE scenario_steps
SET message_type = 'text',
    message_content = '「4,980円で何がわかるの？」
「重いことを言われたら怖い」
「受けたらすぐ決めないといけない？」

その不安は自然です。
凛は、答えを押しつけるために湖を開いていません。

受け取るのは、未来の断定ではなく判断材料です。
進む・待つ・手放すを、自分で選べるようにするための紙です。
凛は急がせません。

興味がある方は、関係整理の入口である「表と裏の恋鑑定（¥4,980）」の案内をご覧ください。

https://rin-tarot-web.vercel.app/?utm_source=line&utm_medium=step_day6'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f'
  AND step_order = 6;

UPDATE scenario_steps
SET message_type = 'text',
    message_content = 'ここまでで渡したかったのは、
彼の気持ちを追いかけ続ける時間から、
行動を観察して判断する時間へ戻ることです。

30代の曖昧な関係では、
結婚の話が出ないこと、
次の約束が置かれないこと、
あなた自身が待つことに慣れてしまうこと、
この3つが重なると苦しさが深くなります。

だから凛は、
進む・待つ・手放すを、自分で選べる軸を作ります。

必要な方だけ、関係整理の入口を使ってください。
まだ早い夜なら、そのまま読んで終わっても大丈夫です。

https://rin-tarot-web.vercel.app/?utm_source=line&utm_medium=step_day7'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f'
  AND step_order = 7;

-- ========================================
-- 2. post-purchase follow-up scenario
-- ========================================

INSERT INTO scenario_steps (id, scenario_id, step_order, delay_minutes, message_type, message_content, created_at)
SELECT
  'post-purchase-followup-v1-step-immediate',
  s.id,
  1,
  0,
  'text',
  '鑑定書を受け取った直後は、答えを急いで探さなくて大丈夫です。

今夜は、鏡の湖が映したあなたの3つの観察だけを手元に置いてください。

1. 鏡の湖が映したあなたの現在地
関係の構造が、どこで止まりやすいか。

2. 鏡の対が示したズレ
言葉と行動のあいだに、どんな温度差があるか。

3. 進む・待つ・手放すのうち、今あなたが置けた一手
次の30日で、自分を責めずに観察できる場所はどこか。

凛は急がせません。
まずは、読み返せる場所に戻るだけで十分です。',
  strftime('%Y-%m-%dT%H:%M:%f', 'now', '+9 hours')
FROM scenarios s
WHERE s.id = 'post_purchase_followup_v1'
ON CONFLICT (scenario_id, step_order) DO UPDATE
SET delay_minutes = excluded.delay_minutes,
    message_type = excluded.message_type,
    message_content = excluded.message_content;

INSERT INTO scenario_steps (id, scenario_id, step_order, delay_minutes, message_type, message_content, created_at)
SELECT
  'post-purchase-followup-v1-step-3d',
  s.id,
  2,
  4320,
  'text',
  '鑑定書を受け取ってから、3日ほど経ちましたね。
今夜は、答え合わせではなく、鏡の湖が映した3つの観察だけを見返してみてください。

1. 鏡の湖が映したあなたの現在地
結婚の話が出ないまま、関係だけが続いていないか。

2. 鏡の対が示したズレ
言葉はやさしいのに、次の約束が置かれないままになっていないか。

3. 進む・待つ・手放すのうち、今あなたが置けた一手
たとえば、追わずに観察する。
あるいは、自分の希望を一文だけ言葉にする。

凛は急がせません。
今日は、読むだけで十分です。',
  strftime('%Y-%m-%dT%H:%M:%f', 'now', '+9 hours')
FROM scenarios s
WHERE s.id = 'post_purchase_followup_v1'
ON CONFLICT (scenario_id, step_order) DO UPDATE
SET delay_minutes = excluded.delay_minutes,
    message_type = excluded.message_type,
    message_content = excluded.message_content;

INSERT INTO scenario_steps (id, scenario_id, step_order, delay_minutes, message_type, message_content, created_at)
SELECT
  'post-purchase-followup-v1-step-7d',
  s.id,
  3,
  5760,
  'text',
  '1週間経ちました。
この7日で、彼の行動・約束の置き方に小さな変化はありましたか。

見てほしいのは、
- 会う話が具体的になったか
- 返事の温度が朝と夜で極端に変わらないか
- 「仕事が落ち着いたら」のまま先送りしていないか

変化があったなら、その一手は「進む」に少し近づいています。
変化がないなら、いまは「待つ」を選んで観察を続けてもいい。

凛は、あなたの代わりに決めません。
でも、自分で選べる軸が育っているかは、ここで見ていきます。',
  strftime('%Y-%m-%dT%H:%M:%f', 'now', '+9 hours')
FROM scenarios s
WHERE s.id = 'post_purchase_followup_v1'
ON CONFLICT (scenario_id, step_order) DO UPDATE
SET delay_minutes = excluded.delay_minutes,
    message_type = excluded.message_type,
    message_content = excluded.message_content;

INSERT INTO scenario_steps (id, scenario_id, step_order, delay_minutes, message_type, message_content, created_at)
SELECT
  'post-purchase-followup-v1-step-30d',
  s.id,
  4,
  33120,
  'text',
  '最初の鑑定から30日。
あの日より、自分の判断が少しでも軽くなっていたら、それは十分な変化です。

32歳、33歳の時間は、数字だけで心を急がせます。
だからこそ凛は、気持ちより行動・約束の置き方を見ます。

この30日で、
- 進むに近づいたか
- まだ待つ段階か
- 手放した方が自分を守れるか

あの夜から、30日。
鏡の湖が、また少し違う表面を映しているかもしれません。
もう一度、現在地を見たい方は、こちらから。

https://rin-tarot-web.vercel.app/?utm_source=line&utm_medium=post_purchase_30d',
  strftime('%Y-%m-%dT%H:%M:%f', 'now', '+9 hours')
FROM scenarios s
WHERE s.id = 'post_purchase_followup_v1'
ON CONFLICT (scenario_id, step_order) DO UPDATE
SET delay_minutes = excluded.delay_minutes,
    message_type = excluded.message_type,
    message_content = excluded.message_content;

INSERT INTO scenario_steps (id, scenario_id, step_order, delay_minutes, message_type, message_content, created_at)
SELECT
  'post-purchase-followup-v1-step-60d',
  s.id,
  5,
  43200,
  'text',
  'あれから60日。
季節が少し動くと、関係の見え方も変わります。

最初に苦しかったのは、彼の気持ちが見えないことより、
結婚の話が出ないまま時間だけが進むことだったはずです。

今のあなたに聞きたいのは、ひとつだけ。
「待つ」を選んでいるなら、それは希望のある待ち方ですか。
それとも、判断を先送りにする待ち方ですか。

鏡の湖は、季節が変わるとズレの見え方も変えます。
必要なら、また現在地だけ見にきてください。',
  strftime('%Y-%m-%dT%H:%M:%f', 'now', '+9 hours')
FROM scenarios s
WHERE s.id = 'post_purchase_followup_v1'
ON CONFLICT (scenario_id, step_order) DO UPDATE
SET delay_minutes = excluded.delay_minutes,
    message_type = excluded.message_type,
    message_content = excluded.message_content;

INSERT INTO scenario_steps (id, scenario_id, step_order, delay_minutes, message_type, message_content, created_at)
SELECT
  'post-purchase-followup-v1-step-90d',
  s.id,
  6,
  43200,
  'text',
  '90日経つと、3-12か月の境界期間の中でも、立っている場所が少しはっきりしてきます。

この3か月で見えたのは、
- 行動が置かれる関係だったのか
- やさしさのまま止まる関係だったのか
- 自分の方が我慢で支えていたのか

凛は急がせません。
でも、ここまで来ると「もう一度見る価値がある関係」かどうかは輪郭が出てきます。

30日後にまた現在地を見たい方は、LINEでひとこと送ってください。
必要な人にだけ、次の整理をお渡しします。',
  strftime('%Y-%m-%dT%H:%M:%f', 'now', '+9 hours')
FROM scenarios s
WHERE s.id = 'post_purchase_followup_v1'
ON CONFLICT (scenario_id, step_order) DO UPDATE
SET delay_minutes = excluded.delay_minutes,
    message_type = excluded.message_type,
    message_content = excluded.message_content;

-- ========================================
-- 3. Verification preview
-- ========================================

SELECT
  scenario_id,
  step_order,
  delay_minutes,
  message_type,
  substr(message_content, 1, 80) AS preview
FROM scenario_steps
WHERE (scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f' AND step_order IN (0, 1, 3, 4, 5, 6, 7))
   OR (scenario_id = 'post_purchase_followup_v1' AND step_order IN (1, 2, 3, 4, 5, 6))
ORDER BY scenario_id, step_order;

COMMIT;
