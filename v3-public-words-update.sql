-- v3.md 正本ベース全文書き換え (2026-04-25)
-- scenario_id: 8ee12685-8ffa-491d-8bed-0c788a02307f (friend_add)
-- 構成: Day0(step=0) + Day1(step=1) + Day3(step=3) + Day4(step=4) + Day5(step=5) + Day6(step=6) + Day7(step=7)
-- Day2(step=2) は v3.md で欠番のため DELETE

-- 1. Day2 (step_order=2) を DELETE
DELETE FROM scenario_steps WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f' AND step_order = 2;

-- 2. step_order=1 (Day1) UPDATE
UPDATE scenario_steps SET message_content = '彼の気持ちがわからない時、
本当に苦しいのは
「好きかどうかが見えないこと」だけではありません。

連絡が来た日は安心する。
来ない日は一気に沈む。

会えた日はまだ大丈夫だと思う。
でも次の約束が曖昧だと、また不安になる。

この揺れは、あなたが弱いからではありません。

気持ちではなく、
関係の進み方が見えないから苦しいのです。

明日は、
「脈あり/脈なし」だけでは判断できない理由をお話しします。'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f' AND step_order = 1;

-- 3. step_order=3 (Day3) UPDATE
UPDATE scenario_steps SET message_content = '「彼に気持ちはあるのかな」

この問いがいちばんつらいと、
凛は知っています。

でも、脈ありか脈なしかだけを見ても
この恋は読み切れないことがあります。

連絡はある。
でも会う話は進まない。

優しい。
でも将来の話になると曖昧になる。

これは「気持ちがない」とは限りません。
ただ、責任ある進展に向かう行動が弱い状態です。

だから見るべきなのは、
気持ちだけではありません。

行動です。

明日は、関係が止まる時に起きやすいパターンをお話しします。'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f' AND step_order = 3;

-- 4. step_order=4 (Day4) UPDATE
UPDATE scenario_steps SET message_content = '曖昧な関係が止まる時、
よくあるのはこの3つです。

1. 好意はあるけれど、責任ある進展を避けている
2. 自分が優しすぎて、期限を切れない
3. 連絡の温度だけを見て、行動を見落としている

どれか1つではなく、
重なっていることも多いです。

だから、彼の気持ちを何度も確認しても
答えが出ないことがあります。

必要なのは、
この恋が今どこにあるのかを整理すること。

そして、
この30日で何を見ればいいのかを決めることです。

明日は、そのための入口鑑定をご案内します。'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f' AND step_order = 4;

-- 5. step_order=5 (Day5) UPDATE
UPDATE scenario_steps SET message_content = 'ここまで、
彼の気持ちがわからない苦しさ、
脈あり/脈なしだけでは判断できない理由、
関係が止まるパターンをお話ししました。

今、あなたの中に残っているのは
「じゃあ私は、何を見ればいいの？」
という問いかもしれません。

凛の表と裏の恋鑑定は、
この恋の表と裏を映す入口鑑定です。

彼の気持ちの有無だけではなく、

・彼の気持ちの温度感
・この恋の現在地
・一番大きい停滞要因
・今やらない方がいいこと
・直近7日で見るサイン
・30日判断の入口

この6つを、あなた専用の鏡の湖レポートにまとめます。

全部を決めるためではありません。
まず見誤りを止めて、
自分で判断できる状態に戻るための鑑定です。

詳しくはこちら
https://rin-tarot-web.vercel.app/?utm_source=line&utm_medium=step_day5'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f' AND step_order = 5;

-- 6. step_order=6 (Day6) UPDATE
UPDATE scenario_steps SET message_content = '「占いって、本当に当たるのかな」
「怖いことを言われたらどうしよう」
「4,980円って高くないかな」

そう思うのは自然です。

凛の鑑定は、
未来を断定して不安を煽るものではありません。

見ていくのは、
今の関係の現在地と、
この30日で何を判断材料にすればいいかです。

彼の気持ちだけを追い続けると、
自分の時間も心も削られてしまいます。

だからこそ、
気持ちより行動を見る。
感情より判断材料を持つ。

その入口として、
表と裏の恋鑑定を用意しています。

今すぐ決めなくても大丈夫です。
でも、現在地を整えたいと思った時は、
ここから見てみてください。

https://rin-tarot-web.vercel.app/?utm_source=line&utm_medium=step_day6'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f' AND step_order = 6;

-- 7. step_order=7 (Day7) UPDATE
UPDATE scenario_steps SET message_content = 'この7日間、
彼の気持ちがわからない恋について
一緒に見てきました。

最後に、凛からひとつだけ置いておきます。

この恋で本当に見るべきなのは、
気持ちの言葉だけではありません。

行動です。

会う提案が具体化するか。
次の約束が相手から出るか。
曖昧な返事が続くか。
30日で何かが変わるか。

表と裏の恋鑑定は、
そこを見るための入口です。

彼の気持ちと、この恋の現在地を確認したい方は
こちらでお待ちしています。

https://rin-tarot-web.vercel.app/?utm_source=line&utm_medium=step_day7

そして、もし鑑定後に

・原因がひとつではなく絡み合っている
・待つか動くかを今月中に決めたい
・距離感や言葉選びまで具体化したい
・進む/待つ/手放すの判断基準がほしい

そう感じた方には、
月下の三つの道鑑定をご案内します。

入口は、鏡の湖で現在地を見ること。
本命は、月下で分岐を読むこと。

焦らなくて大丈夫です。
必要なタイミングで、湖を覗いてください。'
WHERE scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f' AND step_order = 7;

-- 8. Day0 (step_order=0 / delay_minutes=0) を INSERT
INSERT INTO scenario_steps (id, scenario_id, step_order, delay_minutes, message_type, message_content, created_at)
VALUES (
  lower(hex(randomblob(16))),
  '8ee12685-8ffa-491d-8bed-0c788a02307f',
  0,
  0,
  'text',
  '……耳が、ぴくっと動きました。

はじめまして。
猫タロット占い師の、凛です。

あなたがここに来た夜、
境界の湖が少しだけ揺れました。

彼の気持ちがわからない。
この恋を進めていいのかもわからない。

そういう人が、凛のもとにはよく来ます。

でも大丈夫です。
今すぐ答えを決めなくていい。

まずは、この恋が
表ではどう見えていて、
裏ではどこで絡まっているのかを
一緒に見ていきましょう。

もし今、鏡の湖を覗いてみたくなったら
「湖」と送ってください。',
  datetime('now')
);
