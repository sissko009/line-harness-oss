/**
 * テキストメッセージを凛の世界観カード（Flex Message）に変換
 *
 * 修正 2026-04-04:
 * - 長文テキスト（800字超）は背景画像なしの純ダークカードにフォールバック
 *   → 画像オーバーレイ方式は短文向け。長文は確実に表示されるbox方式を使う
 * - URLの前行テキストをボタンラベルに反映（「凛に縁を見せる」固定を解消）
 * - 段落内改行を維持（wrap: true + lineSpacing で安定表示）
 */

/**
 * 背景画像付きオーバーレイで安全に表示できる最大文字数の目安
 * 2:3比率(375px幅) → 高さ562px、padding 48px → テキスト領域514px
 * 日本語sm(13px) × lineHeight1.6 ≈ 21px/行、1行≈20文字
 * 安全圏: ~12行 × 20文字 = 240文字 + セパレーター + マージン
 */
const IMAGE_OVERLAY_MAX_CHARS = 200;

export function wrapInRinCard(text: string): Record<string, unknown> {
  const totalChars = text.length;

  // 長文は画像オーバーレイを使わずダークカード方式にフォールバック
  if (totalChars > IMAGE_OVERLAY_MAX_CHARS) {
    return buildDarkCard(text);
  }
  return buildImageOverlayCard(text);
}

/** 短文用: 背景画像 + 半透明グラデーションオーバーレイ */
function buildImageOverlayCard(text: string): Record<string, unknown> {
  const textContents = buildTextContents(text);

  return {
    type: 'bubble',
    size: 'mega',
    body: {
      type: 'box',
      layout: 'vertical',
      paddingAll: '0px',
      contents: [
        {
          type: 'image',
          url: 'https://rin-assets.pages.dev/banner.jpg',
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
            startColor: '#0B0E2A44',
            centerColor: '#0B0E2A99',
            endColor: '#0B0E2Add',
          },
          paddingAll: '24px',
          justifyContent: 'center',
          contents: textContents,
        },
      ],
    },
  };
}

/** 長文用: 背景画像なし、ダーク背景のbox方式（確実にテキストが収まる） */
function buildDarkCard(text: string): Record<string, unknown> {
  const textContents = buildTextContents(text);

  return {
    type: 'bubble',
    size: 'mega',
    styles: {
      body: { backgroundColor: '#0B0E2A' },
    },
    body: {
      type: 'box',
      layout: 'vertical',
      paddingAll: '24px',
      spacing: 'lg',
      contents: textContents,
    },
  };
}

/** テキストをFlex Message用のcontents配列に変換（共通ロジック） */
function buildTextContents(text: string): Record<string, unknown>[] {
  const paragraphs = text.split(/\n{2,}/).filter(p => p.trim());
  const textContents: Record<string, unknown>[] = [];

  paragraphs.forEach((para, i) => {
    const isFirst = i === 0;
    const hasUrl = para.includes('https://');

    if (hasUrl) {
      const lines = para.split('\n');
      let lastLabel = '凛に縁���見せる';
      lines.forEach(line => {
        if (line.includes('https://')) {
          textContents.push({
            type: 'button',
            action: {
              type: 'uri',
              label: lastLabel,
              uri: line.match(/https?:\/\/[^\s]+/)?.[0] || line,
            },
            style: 'primary',
            color: '#6a5acd',
            height: 'sm',
            margin: 'xl',
          });
        } else if (line.trim()) {
          // URLの前の行をボタンラベル候補として保持
          lastLabel = line.trim().substring(0, 20);
          textContents.push({
            type: 'text',
            text: line.trim(),
            color: '#C9B77D',
            size: 'sm',
            align: 'center',
            margin: 'md',
            wrap: true,
          });
        }
      });
    } else {
      textContents.push({
        type: 'text',
        text: para,
        color: isFirst ? '#C9B77D' : '#f5f0e8',
        size: 'sm',
        wrap: true,
        lineSpacing: '8px',
        margin: i === 0 ? 'none' : 'lg',
      });

      // 最初の段落の後にセパレーター
      if (isFirst) {
        textContents.push({
          type: 'separator',
          color: '#C9B77D44',
          margin: 'lg',
        });
      }
    }
  });

  return textContents;
}
