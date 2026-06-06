#!/usr/bin/env bash
set -euo pipefail

# Register Rin rich menu v12 through the Worker API.
# This script does not read .env files. Pass API_BASE and API_KEY explicitly.
#
# Example:
#   API_BASE="https://line-harness.example.workers.dev" \
#   API_KEY="..." \
#   bash scripts/rich-menu-v12-register.sh

API_BASE="${API_BASE:-}"
API_KEY="${API_KEY:-}"
RICH_MENU_IMAGE="${RICH_MENU_IMAGE:-../LINE/images/richmenu-v12-20260606.jpg}"

# Main product has a confirmed MOSH URL. The mini product URL is not confirmed,
# so the center and guide panels point back to the LP by default.
MAIN_URL="${MAIN_URL:-https://mosh.jp/services/354707?openExternalBrowser=1}"
MINI_URL="${MINI_URL:-https://rin-tarot-web.vercel.app/?utm_source=line&utm_medium=richmenu_mini}"
GUIDE_URL="${GUIDE_URL:-https://rin-tarot-web.vercel.app/?utm_source=line&utm_medium=richmenu_guide}"

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
  "name": "rin-v12-lp-worldview-20260606",
  "chatBarText": "凛のメニュー",
  "areas": [
    {
      "bounds": { "x": 0, "y": 0, "width": 833, "height": 1686 },
      "action": {
        "type": "uri",
        "label": "表と裏の恋鑑定",
        "uri": "$MAIN_URL"
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
        "label": "迷いやすいところ",
        "uri": "$GUIDE_URL"
      }
    }
  ]
}
JSON

echo "Creating rich menu v12..."
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

echo "Done. Rich menu v12 registered: $rich_menu_id"
