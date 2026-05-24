#!/usr/bin/env bash
set -euo pipefail

# Register the Rin v11 rich menu through the Worker API.
# 2026-05-24: LINE方針変更（無料診断Bot廃止）反映版。
#
# 変更点（vs v10b）:
#   - 中央枠: 「鏡の湖チェック」（無料診断Botトリガー）→「鏡の湖ミニ鑑定 ¥480」（MOSH購入導線）
#   - action.type: "message"（テキスト「湖」を送る）→ "uri"（MOSHミニ鑑定ページ）
#   - chatBarText: 「鏡の湖をひらく」→「凛のLINE」
#
# 画像差し替えは design担当の別タスク。画像更新まではv10bの画像を流用可能だが、
# 「鏡の湖チェック」表記が画像内に残っているとUI上の齟齬になるため、新画像で運用する。
#
# This script does not read .env files. Pass values explicitly:
#   API_BASE=https://<worker-domain> API_KEY=<api-key> MINI_URL=<mosh-mini-url> \
#     bash scripts/rich-menu-v11-register.sh
#
# Optional:
#   RICH_MENU_IMAGE=../LINE/images/richmenu-v11-20260524.jpg
#   LP_URL=https://rin-tarot-web.vercel.app/?utm_source=line&utm_medium=richmenu_left
#   MINI_URL=<MOSHの480円ミニ鑑定ページURL>（未確定なら一旦 LP_URL を流用）
#   COLUMN_URL=https://rin-tarot-web.vercel.app/?utm_source=line&utm_medium=richmenu_column

API_BASE="${API_BASE:-}"
API_KEY="${API_KEY:-}"
RICH_MENU_IMAGE="${RICH_MENU_IMAGE:-../LINE/images/richmenu-v11-20260524.jpg}"
LP_URL="${LP_URL:-https://rin-tarot-web.vercel.app/?utm_source=line&utm_medium=richmenu_left}"
MINI_URL="${MINI_URL:-https://rin-tarot-web.vercel.app/?utm_source=line&utm_medium=richmenu_mini}"
COLUMN_URL="${COLUMN_URL:-https://rin-tarot-web.vercel.app/?utm_source=line&utm_medium=richmenu_column}"

if [[ -z "$API_BASE" ]]; then
  echo "ERROR: API_BASE is required" >&2
  exit 1
fi

if [[ -z "$API_KEY" ]]; then
  echo "ERROR: API_KEY is required" >&2
  exit 1
fi

if [[ ! -f "$RICH_MENU_IMAGE" ]]; then
  echo "ERROR: rich menu image not found: $RICH_MENU_IMAGE" >&2
  echo "  Hint: design担当が新画像（鏡の湖ミニ鑑定 ¥480 表記）を作成するまで待つか、" >&2
  echo "        旧 v10b 画像（鏡の湖チェック表記）を流用する場合は RICH_MENU_IMAGE で明示指定。" >&2
  exit 1
fi

tmp_json="$(mktemp)"
tmp_response="$(mktemp)"
cleanup() {
  rm -f "$tmp_json" "$tmp_response"
}
trap cleanup EXIT

cat > "$tmp_json" <<JSON
{
  "size": { "width": 2500, "height": 1686 },
  "selected": true,
  "name": "rin-v11-no-free-diagnosis-20260524",
  "chatBarText": "凛のLINE",
  "areas": [
    {
      "bounds": { "x": 0, "y": 0, "width": 833, "height": 1686 },
      "action": {
        "type": "uri",
        "label": "表と裏の恋鑑定",
        "uri": "$LP_URL"
      }
    },
    {
      "bounds": { "x": 833, "y": 0, "width": 834, "height": 1686 },
      "action": {
        "type": "uri",
        "label": "鏡の湖ミニ鑑定",
        "uri": "$MINI_URL"
      }
    },
    {
      "bounds": { "x": 1667, "y": 0, "width": 833, "height": 1686 },
      "action": {
        "type": "uri",
        "label": "凛のコラム",
        "uri": "$COLUMN_URL"
      }
    }
  ]
}
JSON

echo "Creating rich menu (v11 / no-free-diagnosis)..."
curl -fsS \
  -X POST "$API_BASE/api/rich-menus" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary @"$tmp_json" \
  -o "$tmp_response"

rich_menu_id="$(
  node -e "const fs=require('fs'); const body=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const id=body?.data?.richMenuId || body?.data?.richMenuAliasId || body?.data?.richmenuId || body?.data?.id; if (!id) { console.error(JSON.stringify(body)); process.exit(1); } console.log(id);" "$tmp_response"
)"

echo "Uploading image to rich menu: $rich_menu_id"
curl -fsS \
  -X POST "$API_BASE/api/rich-menus/$rich_menu_id/image" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: image/jpeg" \
  --data-binary @"$RICH_MENU_IMAGE" \
  >/dev/null

echo "Setting default rich menu: $rich_menu_id"
curl -fsS \
  -X POST "$API_BASE/api/rich-menus/$rich_menu_id/default" \
  -H "Authorization: Bearer $API_KEY" \
  >/dev/null

echo "Done. Rich menu v11 registered: $rich_menu_id"
