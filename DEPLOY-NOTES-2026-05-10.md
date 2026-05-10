# 2026-05-10 LINE本番反映 デプロイ手順書

## 前提

- 対象: `占い事業/line-harness-oss`
- 投入SQL: `v3.4-46db-compliance-2026-05-10.sql`
- リッチメニュー登録: `scripts/rich-menu-v10b-register.sh`
- 実行者: こっさん（wrangler認証・Worker API認証が必要）
- Codexは `wrangler --remote`、D1本番投入、Worker deployを実行していない

## 事前確認

```bash
cd 占い事業/line-harness-oss

# 対象DB名を確認
grep -n "database_name\|binding" wrangler.toml

# 本番投入前に対象scenarioの存在確認
npx wrangler d1 execute <db-name> --remote --command "SELECT id, name FROM scenarios WHERE id IN ('8ee12685-8ffa-491d-8bed-0c788a02307f', 'post_purchase_followup_v1');"
```

`post_purchase_followup_v1` が存在しない場合、納品後フォローのINSERTは0件です。先にscenario作成方針を決めてください。

## 1. D1ダンプバックアップ

```bash
cd 占い事業/line-harness-oss
mkdir -p _backup

npx wrangler d1 export <db-name> \
  --output=_backup/d1-backup-2026-05-10-before-v3.4.sql \
  --remote
```

バックアップ完了後、ファイルサイズが0でないことを確認します。

```bash
ls -lh _backup/d1-backup-2026-05-10-before-v3.4.sql
```

## 2. ローカル投入テスト

本番ではなくローカルD1でSQL構文と冪等性を確認します。

```bash
npx wrangler d1 execute <db-name> \
  --file=v3.4-46db-compliance-2026-05-10.sql \
  --local

# 再実行してON CONFLICT/UPDATEが失敗しないことを確認
npx wrangler d1 execute <db-name> \
  --file=v3.4-46db-compliance-2026-05-10.sql \
  --local
```

## 3. 本番投入

```bash
npx wrangler d1 execute <db-name> \
  --file=v3.4-46db-compliance-2026-05-10.sql \
  --remote
```

投入後確認:

```bash
npx wrangler d1 execute <db-name> --remote --command "SELECT scenario_id, step_order, delay_minutes, substr(message_content, 1, 80) AS preview FROM scenario_steps WHERE (scenario_id = '8ee12685-8ffa-491d-8bed-0c788a02307f' AND step_order IN (0,1,3,4,5,6,7)) OR (scenario_id = 'post_purchase_followup_v1' AND step_order IN (1,2,3,4,5,6)) ORDER BY scenario_id, step_order;"
```

## 4. リッチメニュー登録

`API_BASE` と `API_KEY` は本番Worker APIに合わせて指定します。`.env` は読ませません。

```bash
API_BASE="https://<worker-domain>" \
API_KEY="<worker-api-key>" \
RICH_MENU_IMAGE="../LINE/images/richmenu-current-20260425.jpg" \
bash scripts/rich-menu-v10b-register.sh
```

登録後、LINEテストアカウントで以下を確認します。

- 左: `表と裏の恋鑑定` がLPへ遷移する
- 中: `鏡の湖チェック` が「湖」を送信する
- 右: `凛のコラム` が指定URLへ遷移する

## 5. Workerデプロイ

今回のCodex作業ではWorkerコード変更はしていません。既存のWorkerコードを別途修正した場合のみ実行します。

```bash
pnpm install
pnpm build
npx wrangler deploy
```

## 6. 配信動作確認

テストLINEアカウントで確認します。

- 友だち追加直後のあいさつ
- 「湖」送信時の診断Bot起動
- Day1以降のstep配信予約
- リッチメニュー表示
- 納品後フォローscenarioがある場合、step_order 1/2/3/4/5/6 の文面

## ロールバック

最優先はバックアップから復元します。

```bash
npx wrangler d1 execute <db-name> \
  --file=_backup/d1-backup-2026-05-10-before-v3.4.sql \
  --remote
```

リッチメニューだけ戻す場合:

```bash
# 既存メニュー一覧を確認
curl -fsS "$API_BASE/api/rich-menus" \
  -H "Authorization: Bearer $API_KEY"

# 戻したいrichMenuIdをdefaultへ設定
curl -fsS -X POST "$API_BASE/api/rich-menus/<previous-rich-menu-id>/default" \
  -H "Authorization: Bearer $API_KEY"
```

## 既知の未反映点

- `apps/worker/src/routes/webhook.ts` の友だち追加あいさつはコード内にハードコードされており、5/6設計文面とは未整合です。
- `apps/worker/src/services/diagnosis-bot.ts` の診断Bot文面は5/6設計文面とは未整合です。
- 上記2点はSPEC60bの制約上、Codexではコード修正せずエスカレーション対象です。
