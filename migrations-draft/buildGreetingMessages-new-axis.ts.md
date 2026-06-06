# worker 友だち追加あいさつ 新軸（v3.7）コード草稿

> これは **下書き** です。`wrangler deploy` は行いません。
> line-ops・こっさんが APPLY-手順書-2026-06-03.md に従い、
> `apps/worker/src/routes/webhook.ts` の `buildGreetingMessages()` を
> 下記で置換してから build → deploy してください。

## 対象

- ファイル: `apps/worker/src/routes/webhook.ts`
- 関数: `buildGreetingMessages(): Message[]`（おおよそ L505-604）
- 置換範囲: `function buildGreetingMessages()` の本体（`const image1` から `return [image1, text2, text3];` まで）
- **関数シグネチャ・3吹き出し構造（flex画像 / text2 / text3）・import・`export { webhook };` は維持する**
- 画像URL `https://master.rin-assets.pages.dev/greeting-bg.jpg` はそのまま（画像差し替えは別タスク）

## 旧軸 → 新軸の変更点

- 画像内コピー: 「優しいのに進まない関係を／鏡の湖で、まず整える」「彼の気持ちより、行動・約束の置き方を見る場所。」「3-12か月の境界期間を、ひとりで抱えなくていい。」
  → 「ひとりで抱えた違和感を／鏡の湖で、まず置く」「映すのは彼の心ではなく、あなたの直感。」「その違和感は、気のせいじゃない。」（年齢・境界期間の煽りを排除）
- text3（Day0）: 「結婚の話が出ない／32歳や33歳の時間だけが進んでいく」「彼の気持ちを当てる…気持ちより行動・約束の置き方」
  → v3.7 Day0「違和感の肯定／彼でなくあなたの感覚／年齢煽りなし」へ全面差し替え
- text2 はミニ¥480・本命¥4,980の案内予告を維持しつつ、「気持ちより行動」表現を新軸へ寄せる

## 置換後コード

```typescript
function buildGreetingMessages(): Message[] {
  // 吹き出し1: 世界観画像（背景+テキスト上下中央配置）
  const image1: Message = {
    type: 'flex',
    altText: 'ひとりで抱えた違和感を、鏡の湖で、まず置く場所です。',
    contents: {
      type: 'bubble',
      size: 'mega',
      body: {
        type: 'box',
        layout: 'vertical',
        paddingAll: '0px',
        contents: [
          {
            type: 'image',
            url: 'https://master.rin-assets.pages.dev/greeting-bg.jpg',
            size: 'full',
            aspectRatio: '2:3',
            aspectMode: 'cover',
          },
          {
            type: 'box',
            layout: 'vertical',
            position: 'absolute',
            offsetTop: '0px',
            offsetBottom: '0px',
            offsetStart: '0px',
            offsetEnd: '0px',
            background: {
              type: 'linearGradient',
              angle: '0deg',
              startColor: '#0B0E2A88',
              centerColor: '#0B0E2A66',
              endColor: '#0B0E2A88',
            },
            paddingAll: '28px',
            justifyContent: 'center',
            alignItems: 'center',
            contents: [
              { type: 'text', text: '凛', size: 'sm', color: '#C9B77D', align: 'center', weight: 'bold' },
              { type: 'text', text: 'ひとりで抱えた違和感を\n鏡の湖で、まず置く', size: 'xxl', weight: 'bold', color: '#F0F0F5', align: 'center', margin: 'xl', wrap: true },
              { type: 'separator', color: '#C9B77D44', margin: 'xl' },
              { type: 'text', text: '映すのは彼の心ではなく、\nあなたの直感。', size: 'md', color: '#A8A0B8', wrap: true, align: 'center', margin: 'xl' },
              { type: 'text', text: 'その違和感は、気のせいじゃない。', size: 'sm', color: '#C9B77D', align: 'center', margin: 'xl', wrap: true },
              { type: 'text', text: '明日から、判断軸の話を届けます', size: 'sm', color: '#A8A0B8', align: 'center', margin: 'sm' },
            ],
          },
        ],
      },
    },
  } as unknown as Message;

  // 吹き出し2: LINEで届くもの（LINE標準テキスト）
  // 2026-06-03 v3.7: 新軸（違和感の肯定 / 彼でなくあなたの感覚 / 年齢煽りなし）に整合。
  const text2: Message = {
    type: 'text',
    text: `このLINEで届くもの

1. 数日に分けて、判断軸の話（気持ちより行動 / 進む・待つ・手放す）を届けます
2. 軽く試したい方には、鏡の湖ミニ鑑定 ¥480 をご案内します
3. 本格的に整理したい方には、表と裏の恋鑑定 ¥4,980 をご案内します

凛は急がせません。
まずは読むだけでOKです。`,
  } as Message;

  // 吹き出し3: Day0テキスト（LINE標準テキスト・v3.7 Day0 新軸）
  const text3: Message = {
    type: 'text',
    text: `縁がつながりましたね。

優しい言葉はある。
でも、その優しさと行動が、どこかでズレている。
連絡はある。会えばやさしい。
なのに、引っかかるものが消えない。

その違和感を、ひとりで抱えている人へ、ここを開いています。

凛が見るのは、彼の気持ちを当てることではありません。
映すのは、彼の心ではなく、あなたの直感です。
あなたが感じていた違和感は、気のせいじゃない。
そこから、進む・待つ・手放すを自分で選べる軸を作る場所です。

このあと数日に分けて、
「なぜこんなに苦しいのか」
「好意の有無だけでは足りない理由」
「裏がある関係が止まる構造」
を順に届けます。

今日は読むだけでOK。
凛は急がせません。`,
  } as Message;

  return [image1, text2, text3];
}
```

## 適用後の確認観点

- 友だち追加で3吹き出し（画像→届くもの→Day0）が順に届く
- 旧軸文言（32歳/33歳・結婚の話が出ない・彼の気持ちを当てる）が出ない
- `pnpm build` が型エラーなく通る（`Message` 型・import は無変更）
