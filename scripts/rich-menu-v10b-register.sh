#!/usr/bin/env bash
set -euo pipefail

# Register the Rin v10b rich menu through the Worker API.
# This script does not read .env files. Pass values explicitly:
#   API_BASE=https://<worker-domain> API_KEY=<api-key> bash scripts/rich-menu-v10b-register.sh
#
# Optional:
#   RICH_MENU_IMAGE=../LINE/images/richmenu-current-20260425.jpg
#   LP_URL=https://rin-tarot-web.vercel.app/?utm_source=line&utm_medium=richmenu_left
#   CHECK_TEXT=湖
#   COLUMN_URL=https://rin-tarot-web.vercel.app/?utm_source=line&utm_medium=richmenu_column

API_BASE="${API_BASE:-}"
API_KEY="${API_KEY:-}"
RICH_MENU_IMAGE="${RICH_MENU_IMAGE:-../LINE/images/richmenu-current-20260425.jpg}"
LP_URL="${LP_URL:-https://rin-tarot-web.vercel.app/?utm_source=line&utm_medium=richmenu_left}"
CHECK_TEXT="${CHECK_TEXT:-湖}"
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
  "name": "rin-v10b-46db-20260510",
  "chatBarText": "鏡の湖をひらく",
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
        "type": "message",
        "label": "鏡の湖チェック",
        "text": "$CHECK_TEXT"
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

echo "Creating rich menu..."
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

echo "Rich menu registered and set as default: $rich_menu_id"
