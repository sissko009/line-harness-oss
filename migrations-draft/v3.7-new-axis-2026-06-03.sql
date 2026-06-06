-- v3.7 新軸（裏がある関係 / 違和感の肯定）反映 SQL（2026-06-03 下書き）
-- ============================================================================
-- これは「下書き」です。wrangler / D1本番への適用は line-ops・こっさんが
-- APPLY-手順書-2026-06-03.md に従って手動で行ってください。
--
-- 適用前提（v3.4 の構造を厳守）:
--   - friend_add scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f'
--       対象 step_order = 0,1,3,4,5,6,7（v3.4 と同一・step_order 2 は触らない）
--   - 納品後フォロー scenario_id = 'post_purchase_followup_v1'
--       対象 step_order = 1,2,3,4,5,6（immediate/3d/7d/30d/60d/90d）
--   - テーブル: scenario_steps（id, scenario_id, step_order, delay_minutes,
--       message_type, message_content, created_at）
--   - friend_add 側は v3.4 同様 UPDATE のみ（行は既存・新規 INSERT しない）
--   - 納品後フォロー側は v3.4 同様 SELECT FROM scenarios + ON CONFLICT で UPSERT
--       （post_purchase_followup_v1 が存在しなければ 0 行＝設計通り）
--
-- 新軸の正本:
--   - 占い事業/LINE/ステップ配信v3.md（v3.7）
--   - 占い事業/LINE/ステップ配信v3_短文化版_Day5-7.md
--   - 占い事業/CLAUDE.md（5要素 / 倫理の歯止め / 凛固有資産）
--
-- v3.4 からの変更点（旧軸キーワード排除）:
--   - 「彼の気持ちタロット / 彼の気持ちの温度感 / 彼の気持ちを当てる」削除
--   - 「32歳 / 33歳」「結婚の話が出ない（断定的煽り）」「婚活疲れ」削除
--   - 「3-12か月の境界期間」は煽り文脈では使わない
--   - 「縁の絡まり / 眠り縁」未使用
--   新軸:
--   - 「あなたが感じた違和感は気のせいじゃない」
--   - 「映すのは彼の心ではなくあなたの直感」
--   - 行動は事実で言い切る／気持ちは断定しない＋境界併記
--   - 進む／待つ／手放す・「凛は急がせません」
--   - Day5 6点リスト「彼の気持ちの温度感」→「彼の言葉と行動のズレ（事実として観察できる点）」
--   - 第三者（配偶者・相手）は占わない／卒業を正常な出口にする 等の倫理の歯止め
--
-- 安全:
--   - UPDATE 述語は scenario_id + step_order に限定
--   - 納品後フォローは ON CONFLICT (scenario_id, step_order) DO UPDATE
--   - 本番投入前に D1 dump backup を取得（APPLY-手順書-2026-06-03.md 参照）
-- ============================================================================

BEGIN;

-- ========================================
-- 1. friend_add scenario: Day0/1/3/4/5/6/7（新軸へ差し替え）
-- ========================================

-- Day 0 - 出会い（彼を読む→あなたの感覚を取り戻す）
UPDATE scenario_steps
SET message_type = 'text',
    message_content = '優しい言葉はある。
でも、その優しさと行動が、どこかでズレている。
連絡はある。会えばやさしい。
なのに、引っかかるものが消えない。

その違和感を、ひとりで抱えている人へ、ここを開いています。

凛が見るのは、彼の気持ちを当てることではありません。
映すのは、彼の心ではなく、あなたの直感です。
あなたが感じていた違和感は、気のせいじゃない。
そこから、進む・待つ・手放すを自分で選べる軸を作る場所です。

今日は読むだけでOK。
凛は急がせません。'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f'
  AND step_order = 0;

-- Day 1 - 共通感情（答えは出てるのに動けない）
UPDATE scenario_steps
SET message_type = 'text',
    message_content = '別れた方がいい。
最低なのは分かってる。
愚かなのも、自分が一番よく分かってる。

苦しいのは、彼の気持ちが見えないことだけではありません。
答えはもう、自分の中に出ている。
それなのに足が止まる──その自分を、責めてしまうことです。

世間は「あなたは選ばれる価値がある」「一人を怖がらないで」と言う。
でも本当に揺らいでいるのは、自分の感覚を信じていいのか分からないこと。
ここには、誰も触れてくれません。

凛は、そこに触れます。
あなたが感じた違和感を、まず「気のせいじゃない」と置くところから始めます。'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f'
  AND step_order = 1;

-- Day 3 - 気持ちの推測だけでは足りない（行動を見る・境界併記）
UPDATE scenario_steps
SET message_type = 'text',
    message_content = '優しい言葉は、いくらでも出る。
でも、優しさと進展は別のものです。

見てほしいのは、気持ちの推測ではなく行動です。
たとえば、

- 会う提案が、いつも曖昧なまま流れる
- 連絡はあるのに、肝心な話だけ避けられる
- 「今は」「落ち着いたら」が、何度も繰り返される
- あなたにだけ、返信の温度が違う

凛は、これを点でなく構造で映します。
ただし、「会う提案が2回あった」は事実として言い切りますが、「だから脈あり」という意味にはしません。
気持ちは、行動からは断定できないからです。
事実は事実のまま渡し、意味づけはあなたの手に残します。'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f'
  AND step_order = 3;

-- Day 4 - 関係が止まるパターン（裏がある関係4+1タイプ横断・第三者不可）
UPDATE scenario_steps
SET message_type = 'text',
    message_content = '裏がある関係が止まりやすいのは、止まり方が「彼の問題」ではなく「あなたの感覚が混ざってしまっている」時です。
あなたが今いるのは、どれに近いですか。

1. 優しいのに、行動に引っかかる
   「大好き」が増えたのに違和感が消えない。気づくとSNSを見返している。

2. やめた方がいいと分かっているのに、戻される
   優しさや「今は無理だけど」に、何度も期待を立て直してしまう。

3. 離してくれない・一番になれない
   会わない期間は無気力。会えばまた大好きに戻る。これは恋か、依存か。

4. 好きと言うのに、立場をくれない
   優しい・連絡はある・好きとは言う。でも「彼女」「その先」には進まない。

5. 答えは出てるのに、足が止まる
   許したのに信じられない。別れたいのに離れられない。

鏡の湖は、止まり方の種類を見分けるために使います。
止まり方が見えれば、それが「彼の気持ち次第」ではなく「あなたが選べる現在地」だと分かります。

凛は、相手の配偶者や第三者がどうなるかは映しません。
映すのは、いつでもあなた自身の現在地と判断です。'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f'
  AND step_order = 4;

-- Day 5 - 主導線「表と裏の恋鑑定」（6点リスト新軸・MOSH CTA）
UPDATE scenario_steps
SET message_type = 'text',
    message_content = 'ここまで読んで、
「彼の気持ちを当てるより、止まっている自分を映す言葉がほしい」
と感じているなら、それは整えどきです。

表と裏の恋鑑定では、次の6点を返します。

- 彼の言葉と行動のズレ（事実として観察できる点）
- この関係の現在地
- 一番大きい停滞要因
- 今やらない方がいいこと
- 直近7日で見るサイン
- 30日判断の入口（進む／待つ／手放す）

彼の気持ちは断定しません。
代わりに、行動は事実として静かに言い切り、そのうえで判断はあなたに戻します。
渡すのは、あなたが感じた違和感が気のせいじゃなかったと確かめ、自分の感覚を信じ直すための紙です。

興味がある方は、関係整理の主商品である「表と裏の恋鑑定（¥4,980）」の案内をご覧ください。
まだ深い鑑定までは早い方は、まずここまでの配信だけ受け取って終えても大丈夫です。

▼ 表と裏の恋鑑定（¥4,980）
https://mosh.jp/services/354707?openExternalBrowser=1&utm_source=line&utm_medium=step_day5'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f'
  AND step_order = 5;

-- Day 6 - 購入不安の解消（FAQ・第三者占わない歯止め・MOSH CTA）
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

──よく聞かれる3つに、短くお返事します。

相手のいる人との関係でも見てもらえますか？
あなた自身の現在地と判断なら、映します。
ただし、相手の配偶者やお相手が「どうなるか」「別れるか」は占いません。
凛が映すのは、いつでもあなたの側です。

重い相談でも大丈夫ですか？
凛の湖が映せるのは、関係の現在地と、進む・待つ・手放すの判断軸です。
それ以外のこと（家族・仕事・健康・心の状態など）は、凛より、もっと近くにいる人や専門の方の声のほうが、深く届くかもしれません。

鑑定書には何が書かれていますか？
言葉と行動のズレ／関係の現在地／停滞要因／今やらない方がいいこと／7日で見るサイン／30日判断の入口（進む・待つ・手放す）、の6点を書き起こします。
彼の気持ちは断定せず、観察できる行動を事実として置き、判断はあなたに戻します。

興味がある方は、関係整理の主商品である「表と裏の恋鑑定（¥4,980）」の案内をご覧ください。
まだ申し込むほどではない方は、ここまでの配信を判断材料として残してください。

▼ 表と裏の恋鑑定（¥4,980）
https://mosh.jp/services/354707?openExternalBrowser=1&utm_source=line&utm_medium=step_day6'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f'
  AND step_order = 6;

-- Day 7 - まとめ + 弱押し（卒業の明示・MOSH CTA）
UPDATE scenario_steps
SET message_type = 'text',
    message_content = 'ここまでで渡したかったのは、
彼の気持ちを追いかけ続ける時間から、
自分の感覚を信じ直す時間へ戻ることです。

裏がある関係では、
優しい言葉ほど裏を読んでしまうこと、
問い詰められずSNS監視や我慢の側へ逃げてしまうこと、
そして矛先が「止まれない自分」へ向いてしまうこと、
この3つが重なると、苦しさが深くなります。

だから凛は、
あなたが感じた違和感を「気のせいじゃない」と置き、
進む・待つ・手放すを、自分で選べる軸を作ります。
そして、自分で判断できるようになったら、来なくていい場所であろうとします。

必要な方だけ、関係整理の主商品を使ってください。
深く見るなら「表と裏の恋鑑定（¥4,980）」です。
まだ早い夜なら、そのまま読んで終わっても大丈夫です。

▼ 表と裏の恋鑑定（¥4,980）
https://mosh.jp/services/354707?openExternalBrowser=1&utm_source=line&utm_medium=step_day7'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f'
  AND step_order = 7;

-- ========================================
-- 2. post-purchase follow-up scenario（30/60/90日フォロー・新軸へ）
-- ========================================

-- step 1: 直後（immediate）
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
彼の言葉と行動のあいだに、どんな温度差があったか（事実として観察できる点）。

3. 進む・待つ・手放すのうち、今あなたが置けた一手
次の30日で、自分を責めずに観察できる場所はどこか。

あなたが感じた違和感は、気のせいじゃない。
凛は急がせません。まずは、読み返せる場所に戻るだけで十分です。',
  strftime('%Y-%m-%dT%H:%M:%f', 'now', '+9 hours')
FROM scenarios s
WHERE s.id = 'post_purchase_followup_v1'
ON CONFLICT (scenario_id, step_order) DO UPDATE
SET delay_minutes = excluded.delay_minutes,
    message_type = excluded.message_type,
    message_content = excluded.message_content;

-- step 2: 3日後
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
優しい言葉と行動のズレを、まだ「気のせい」にしていないか。

2. 鏡の対が示したズレ
言葉はやさしいのに、次の約束が置かれないままになっていないか（事実として観察できる点）。

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

-- step 3: 7日後
INSERT INTO scenario_steps (id, scenario_id, step_order, delay_minutes, message_type, message_content, created_at)
SELECT
  'post-purchase-followup-v1-step-7d',
  s.id,
  3,
  5760,
  'text',
  '1週間経ちました。
この7日で、彼の言葉と行動のあいだに、小さな変化はありましたか。

見てほしいのは（事実として観察できる点）、
- 会う話が具体的になったか
- 返事の温度が朝と夜で極端に変わらないか
- 「落ち着いたら」のまま先送りしていないか

ただし、変化があっても、それを「脈あり」と決めつけなくて大丈夫です。
事実は事実のまま置いて、意味づけはあなたの手に残します。

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

-- step 4: 30日後（再来店のリマインドは「節目」として）
INSERT INTO scenario_steps (id, scenario_id, step_order, delay_minutes, message_type, message_content, created_at)
SELECT
  'post-purchase-followup-v1-step-30d',
  s.id,
  4,
  33120,
  'text',
  '最初の鑑定から30日。
あの日より、自分の判断が少しでも軽くなっていたら、それは十分な変化です。

凛は、彼の気持ちを当てるのではなく、言葉と行動のズレを事実として映してきました。
そして、あなたが感じた違和感が気のせいじゃなかったことを、置き直してきました。

この30日で、
- 進むに近づいたか
- まだ待つ段階か
- 手放した方が自分を守れるか

あの夜から、30日。
鏡の湖が、また少し違う表面を映しているかもしれません。
状況が動いた節目に、もう一度、現在地を見たい方は、こちらから。

▼ 表と裏の恋鑑定（¥4,980）
https://mosh.jp/services/354707?openExternalBrowser=1&utm_source=line&utm_medium=post_purchase_30d',
  strftime('%Y-%m-%dT%H:%M:%f', 'now', '+9 hours')
FROM scenarios s
WHERE s.id = 'post_purchase_followup_v1'
ON CONFLICT (scenario_id, step_order) DO UPDATE
SET delay_minutes = excluded.delay_minutes,
    message_type = excluded.message_type,
    message_content = excluded.message_content;

-- step 5: 60日後
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
優しい言葉と行動のズレを、ひとりで抱えていたことだったはずです。

今のあなたに聞きたいのは、ひとつだけ。
「待つ」を選んでいるなら、それは自分の感覚に納得した待ち方ですか。
それとも、判断を先送りにする待ち方ですか。

鏡の湖は、季節が変わるとズレの見え方も変えます。
必要なら、また現在地だけ見にきてください。
凛は急がせません。',
  strftime('%Y-%m-%dT%H:%M:%f', 'now', '+9 hours')
FROM scenarios s
WHERE s.id = 'post_purchase_followup_v1'
ON CONFLICT (scenario_id, step_order) DO UPDATE
SET delay_minutes = excluded.delay_minutes,
    message_type = excluded.message_type,
    message_content = excluded.message_content;

-- step 6: 90日後（卒業を正常な出口に）
INSERT INTO scenario_steps (id, scenario_id, step_order, delay_minutes, message_type, message_content, created_at)
SELECT
  'post-purchase-followup-v1-step-90d',
  s.id,
  6,
  43200,
  'text',
  '90日経つと、立っている場所が少しはっきりしてきます。

この3か月で見えたのは、
- 行動が置かれる関係だったのか
- やさしさのまま止まる関係だったのか
- 自分の感覚を、我慢の側に預けてしまっていたのか

凛は急がせません。
そして、自分で判断できるようになったら、来なくていい場所であろうとします。
卒業は、この場所の正常な出口です。

それでも状況が動いた節目に、もう一度現在地を見たくなったら、
LINEでひとこと送ってください。
必要な人にだけ、次の整理をお渡しします。',
  strftime('%Y-%m-%dT%H:%M:%f', 'now', '+9 hours')
FROM scenarios s
WHERE s.id = 'post_purchase_followup_v1'
ON CONFLICT (scenario_id, step_order) DO UPDATE
SET delay_minutes = excluded.delay_minutes,
    message_type = excluded.message_type,
    message_content = excluded.message_content;

-- ========================================
-- 3. Verification preview（適用後に目視する）
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

-- 旧軸キーワード残存チェック（0件であること）
SELECT scenario_id, step_order, '旧軸キーワード残存' AS warn
FROM scenario_steps
WHERE scenario_id IN ('8ee12685-8ffa-491d-8bed-0c788a02307f', 'post_purchase_followup_v1')
  AND (
       message_content LIKE '%彼の気持ちタロット%'
    OR message_content LIKE '%彼の気持ちの温度感%'
    OR message_content LIKE '%彼の気持ちを当てる%'
    OR message_content LIKE '%32歳%'
    OR message_content LIKE '%33歳%'
    OR message_content LIKE '%婚活疲れ%'
    OR message_content LIKE '%結婚の話が出ない%'
    OR message_content LIKE '%縁の絡まり%'
    OR message_content LIKE '%眠り縁%'
  );

COMMIT;
