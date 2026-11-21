---
name: taste
description: angelcore / cloud-trance / hyperpop 系統のミュージックビデオやショートフォーム編集のためのクリエイティブ・ディレクション層。名前付きジャンルの美学ボキャブラリー、ムード・色・光のシステム、ビート同期の編集文法、そして b-roll 生成から配信までを ECC の動画スキルでつなぐパイプラインを提供します。動画が単に機能的であるだけでなく意図的に感じられる必要がある場合（ミュージックビデオ、ファンカム、ムードボード主導のリール、AI 生成 b-roll に一貫したビジュアルの方向性を与えたい場合）に使用します。
origin: ECC
---

# Taste

AI 動画に関するアドバイスの多くは、*フレームをどうレンダリングするか* で止まっています。このスキルはその上のレイヤーです。
**フレームがどう見えるべきか、どの順序で、どのリズムでカットすれば、結果が生成物の寄せ集めではなく、一つの意図的なものとして読めるか** を扱います。

このスキルには特定のテイストが込められています。**angelcore / cloud-trance / hyperpop** 系統（Bladee の "Silver Surfer" 期のエーテリアルなトランスと重厚な angelcore の交差）です。保存した Reels のコーパスと、約 70 項目のビジュアルジャンルライブラリの巡回から抽出しました。意図的に偏りのある（独自の立場を打ち出した）内容にしています。テイストは視点であり、メニューではありません。

> 付属ファイル `references/genre-taxonomy.md` に、名前付きジャンルの完全なカタログがあります。
> このファイルは実践レイヤー（ムード、文法、パイプライン、ビートにマッピングしたショットプラン）です。

## When to Activate

- **ミュージックビデオ**、リリックビデオ、ファンカム、ビジュアライザーを作る場合。
- 情報よりも *フィーリング* が重要なショートフォームの**編集 / リール**を作る場合。
- **AI b-roll 生成**（fal.ai、Veo、Kling など）を行い、プロンプトに場当たり的な雰囲気ではなく一貫した方向性が必要な場合。
- レンダリングの前に、**ムードボード**を組み立てる、またはビジュアルジャンルを選ぶ場合。
- ユーザーが「taste」「make it feel like X」「give it a direction」「angelcore」「cloud trance」「hyperpop edit」「Bladee」「dreamcore」と言う、または保存済みのリファレンスを挙げた場合。
- 現在の編集は機能しているが、平板、ありきたり、AI スロップ、スタイル的に一貫していないと感じられる場合。

このスキルは `video-editing`（メカニクス）と `remotion-video-creation`（レンダラー）の**上に**位置します。*どうやるか* にはそれらを使い、*何を、なぜ* にはこのスキルを使います。

## Core Thesis

1. **テイストは最後のレイヤーだが、最初に決めなければならない。** `video-editing` はテイストが最後の人間によるパスだと正しく述べています。落とし穴は、テイストを最後に決めると、上流のすべての生成とカットが当て推量になることです。最初のプロンプトの*前に*方向性を決め、それにすべてを制約させます。
2. **一貫性は新奇性に勝る。** 30 ショットにわたって実行された一つのルックは、30 通りのルックに勝ります。名前付きジャンル（後述）は、一貫性を無料で手に入れる制約です。
3. **素材ではなく曲に合わせてカットする。** ミュージックビデオでは、タイムラインは波形です。すべてのハードカットはビートまたはトランジェントに乗せます。フレーム計算はパイプラインのセクションにあります。
4. **選んで生成し、容赦なく編集する。** AI は存在しない b-roll を作りますが、テイストは作りません。それでも 80% は捨てることになります。

## The Aesthetic Vocabulary (distilled)

リファレンスコーパスは、*名前付き*ビジュアルジャンルの大きなライブラリを巡っています。完全なリストは `references/genre-taxonomy.md` にあります。有用なのは 70 個の名前を暗記することではなく、**ジャンル名がプロンプトとグレーディングを兼ねた完全なプリセットである**と捉えることです。一つ選べば、そのパレット、テクスチャ、ライティング、被写体を一式として引き継げます。

ジャンルはファミリーにまとまります。**主**ファミリーを一つ選び、**アクセント**は多くても一つにします。

| Family | Genres in it | Reads as |
|--------|-------------|----------|
| **Ethereal / divine** | spiritualism, glacial folk, beacons, zen core, fairy tale | 無重力、神聖、発光、柔らかい |
| **Hyperpop / Y2K-cyber** | cyberdelia, acid house, acid nora, neo aggressano, new liquid | 光沢、クローム、ネオン、カワイイ・サイバー |
| **Dark / occult** | dark academia, smoke nostalgia, communist core, abstract tech | 高コントラスト、不吉、グレイン |
| **Retro / print** | retro surfers, art deco, adventure pulp, classic advertising, magazine collage, bumper stickers | フラット、グラフィック、ハーフトーン、ノスタルジック |
| **Organic / textural** | microbiology core, weaving patterns, fruitage retro, cozy blanket, pacific punk wave | 触感的、マクロ、織物的、濡れた質感 |
| **Systemic / data** | numbers, mazes, code web, heatmap, pixel, 8-bit | グリッド状、ジェネレーティブ、図式的 |

**現在のプロジェクトでは**、主は **Ethereal / divine**、アクセントは **Hyperpop / Y2K-cyber** です。つまり、神聖な光と結晶のブルームに、クロームとネオンで句読点を打ちます。この組み合わせこそが angelcore × cloud-trance のブリーフです。

## The Mood System — angelcore × cloud-trance

最も強力なリファレンスリールから直接抽出したものです。これが具体的なグレードです。

### Palette
- **ベース:** ニアブラックの虚空（#05060a）とボーンホワイト（#f4f1ea）。ほとんどのフレームはどちらか一方です。
- **ディバインアクセント:** 溶けた金 / 燠火のオレンジ（#ffb24d → #ff7a18）。闇の中の*唯一の暖かい光*です。
- **クリスタリンアクセント:** 虹色のバイオレット→シアン→マゼンタのボケ（#8a6bff, #4fc3ff, #ff6ad5）。ハイパーポップのブルームで、明るいフレームで使います。
- **デンジャーアクセント（控えめに）:** モノクロの上に光る単一の赤（#ff2a2a）。ショックカットを 1〜2 回行う場合のみ使います。
- **ハイパーポップの被写体:** 青空を背にしたキャンディピンクの髪 / クローム / 光沢のある白。

ルール: **1 ショットにつきアクセントは 1 つ。** 金は暗いフレームに、虹色は明るいフレームに置きます。一つのショットに両方が入ることは決してありません。

### Light & texture
- 闇を貫く単一の暖かい光源（燠火のブルーム、神々しい光の筋）。高コントラストで、深い黒。
- 結晶 / グリッターのボケ、レンズフレア、ブルーム、ライトリーク。汚れではなく*天上的*に。
- 暗いフレームにはフィルムグレインと控えめな色収差。明るいフレームにはクリーンな光沢。
- 余白へのマクロディテール: 黒の中央に置いたヒーローオブジェクト（鍵、目、歯車、花びら、水）。
- 被写体: 翼のある人物、雲、光輪、天使、結晶構造、キャンディ・サイバーのポートレート。

### Motion
- ゆっくりとした、浮遊する、無重力のカメラ（ドリフト、スロープッシュ、スローオービット）。これが*クラウド*トランスです。
- スピードのバーストはドロップでのみ。それ以外はすべて呼吸するように。
- 上昇するパーティクル（燠火、塵、グリッター）。上方向の動きは昇天を意味します。

## The Editing Grammar (distilled)

リファレンスの編集から、繰り返し現れてこのスタイルを定義するテクニックです。

1. **ビートに固定したハードカット。** ヴァースやドロップではディゾルブを使いません。キックでカットします。目が BPM を感じるようにします。
2. **黒の上のヒーローマクロインサート。** 黒い余白の中央に置いた、鮮明な単一オブジェクトを 1〜2 ビート保持してからカットします。これらのリズミカルなモンタージュがクラウドトランスの署名です。
3. **ブルーム / 爆発リビール。** トランジェントで白または燠火のブルームがフレームを白飛びさせ、次のショットへとつながります。「ディバインフラッシュ」トランジション。
4. **モノクロ上のカラーポップ。** 一区間を白黒で進め、ダウンビートで単一の色付き要素（赤い目、金の炎、ピンクの髪）が突き抜けます。
5. **ドロップに向けたスピードランプ。** ドロップ直前の最後の 1 小節で素材の速度をスローから高速へ段階的に上げ（スピードランプ）、1 拍目でテンポに合わせてハードカットします。
6. **キャプションのキーワードハイライト（トーキングヘッド / リリックのセクションのみ）。** 全大文字で、1〜2 語をアクセントカラーでハイライトし、ボーカルに同期します。リリックビデオには使い、純粋なビジュアライザーには使いません。
7. **リアクション PiP（解説 / 編集コメンタリーのみ）。** b-roll の上にトーキングヘッドを重ねるピクチャーインピクチャー。ミュージックビデオ自体では対象外ですが、コーパスで多用されているため記載しています。

**Do-nots:** テンポのあるセクションでのクロスフェードトランジション。1 ショットに複数のアクセントカラー。音楽的フレーズを超えて保持されるショット。読み取れるオンスクリーン UI クローム（クロップで除去する）。1 本のタイムラインでの異なるアスペクト比の混在。

## The Pipeline — mixing the ECC video skills

このスキルは指揮者です。各 ECC スキルは楽器です。レイヤーを飛ばしてはいけません。

```
0. TASTE (this skill)        decide genre + mood + grammar BEFORE anything renders
1. STRUCTURE (video-editing) map the song: timestamps for intro/verse/drop/bridge/outro
2. GENERATE (fal-ai-media)   make b-roll per genre prompt-presets; throw away 80%
3. CUT (video-editing/FFmpeg) beat-cut + reframe to 9:16; assemble selects on the grid
4. COMPOSE (remotion-video-creation) overlays, blooms, lyric text, beat-synced sequencing
5. MOTION (motion-* skills)  easing curves, light-leak/particle motion, transition timing
6. AUDIO (fal-ai-media)      transition risers/impacts to sell the cuts (track itself is in Ableton)
7. POLISH                    grade to the palette above, final pacing pass, export
8. DISTRIBUTE (content-engine) platform-native versions + caption/cover
```

| Step | ECC skill to load | What it does here |
|------|-------------------|-------------------|
| Structure & cut | `video-editing` | FFmpeg のカット / 結合 / リフレーム、EDL、シーン / 無音検出 |
| Generate b-roll | `fal-ai-media` | ジャンルプリセットごとの画像 / 動画モデル |
| Compose & overlay | `remotion-video-creation` | ビート同期の `<Sequence>`、テキスト、ブルーム、マスク |
| Motion timing | `motion-foundations`, `motion-patterns`, `motion-advanced` | イージング、スプリング、光 / パーティクルのモーション |
| Server-side video | `videodb` | スマートリフレーム、素材が大きい場合のインデックス化 |
| Distribution | `content-engine` | プラットフォームごとのカット、カバー、キャプション |
| Voice/lyric VO | `video-editing` (ElevenLabs section) | 音声レイヤーが必要な場合のみ |

## Beat Math (lock cuts to the song)

現在のトラックは **138 BPM、B minor** です。定数は次のとおりです。

- `seconds_per_beat = 60 / 138 = 0.43478s`
- `frames_per_beat   = fps × 0.43478`  →  **24fps: 10.43**, **30fps: 13.04**, **60fps: 26.09**
- `1 bar (4 beats)   = 1.7391s`  →  30fps: **52.17 frames**
- `8-bar phrase      = 13.913s`  →  トラックのループ長

Remotion では、すべての `from={}` をビートにスナップします。
```ts
const FPS = 30;
const BPM = 138;
const beat = (n: number) => Math.round(n * (60 / BPM) * FPS); // beat(n) → frame
// cut on beats 0,4,8,... :  <Sequence from={beat(0)} durationInFrames={beat(4)}> ...
```

## Beat-Mapped Shot Plan (this music video)

曲の構成（プロジェクト自身のノートより）は
**Intro → Verse → Drop → Bridge → Drop → Outro（約 2:05）** です。各セクションにテイストをマッピングします。

| Section | Genre/mood lean | Grammar | Shot ideas |
|---------|-----------------|---------|------------|
| **Intro** | Ethereal/divine、ニアブラック | スロープッシュ、カットなし | 虚空の中の燠火のブルーム、一筋の金の光、舞い上がる塵 |
| **Verse** | Dark + 黒の上のヒーローマクロ | 2 ビートごとのハードカット | 鍵、目、歯車、水滴、花びら。リズミカルなマクロモンタージュ |
| **Drop** | Hyperpop ブルーム + クリスタリン | スピードランプで入り、1 拍目でカット、高速 | キャンディピンクの人物、クローム、虹色のボケ、翼のある昇天 |
| **Bridge** | Spiritualism、無重力 | 長尺のワンショットを一つだけ保持、カラーポップ | 雲 + 光輪。単一の赤いアクセントが一度だけ突き抜ける |
| **Drop 2** | Drop と同じで、強度を上げる | トランジェントにディバインフラッシュのブルームを追加 | 翼が開く、グリッターのバースト、ライトリークを最大に |
| **Outro** | Glacial folk、冷たく静か | ゆっくりフェードして黒へ | 溶けていく結晶構造、燠火が消える |

## fal.ai Prompt Presets (per mood)

`fal-ai-media` と併用します。各プリセットは、プロジェクトのパレットにレンダリングしたジャンルです。すべてに
`9:16, vertical, cinematic, film grain, volumetric light, no text, no watermark` を付加します。

- **Divine void:** "a single molten-gold ember bloom rising in an infinite near-black void,
  deep shadow, one warm light source, weightless dust particles, holy, high contrast"
- **Macro hero:** "extreme macro of an antique brass key / a human eye / interlocking gears,
  centered on pure black negative space, razor-sharp detail, single rim light"
- **Crystalline bloom:** "iridescent violet-cyan-magenta crystalline bokeh, glittering light
  refraction, dreamy lens flares, heavenly glow, soft focus, hyperpop angelcore"
- **Candy-cyber portrait:** "candy-pink-haired figure, glossy chrome accents, bright blue sky,
  Y2K hyperpop, clean gloss, saturated, kawaii-cyber"
- **Winged ascension:** "a winged figure ascending into clouds, halo of light, bone-white and
  gold, volumetric god-rays, ethereal, religious iconography, soft"
- **Cold outro:** "pale crystalline ice structure slowly dissolving, glacial folk, cold blue
  and bone white, minimal, calm, fading to black"

プリセットごとに 6〜10 個を生成し、2〜3 個を残します。モーションについては、静止画を image-to-video モデルでアニメーション化するか、短いクリップを直接生成します。カメラの動きは上記 Motion セクションのルールに従い、ゆっくりに保ちます。

## FFmpeg Recipes (cut + reframe)

```bash
# Reframe any landscape/raw clip to 9:16 (center crop)
ffmpeg -i in.mp4 -vf "crop=ih*9/16:ih,scale=1080:1920" v.mp4

# Beat-cut a clip to exactly N beats at 138 BPM (e.g. 2 beats = 0.8696s)
ffmpeg -i in.mp4 -t 0.8696 -c copy beat2.mp4

# Concatenate beat-selects into the verse montage
for f in selects/*.mp4; do echo "file '$f'"; done > concat.txt
ffmpeg -f concat -safe 0 -i concat.txt -c copy verse.mp4

# Strip UI chrome / status bar from a screen-recorded reference (crop top+bottom)
ffmpeg -i reel.mp4 -vf "crop=iw:ih-300:0:150" clean.mp4
```

## Remotion Composition Skeleton (beat-synced)

```tsx
import { AbsoluteFill, Sequence, Video, Img, useCurrentFrame, interpolate } from "remotion";

const FPS = 30, BPM = 138;
const beat = (n: number) => Math.round(n * (60 / BPM) * FPS);

const Bloom: React.FC = () => {
  const f = useCurrentFrame();
  const o = interpolate(f, [0, 3, 12], [0, 1, 0], { extrapolateRight: "clamp" }); // divine flash on a transient
  return <AbsoluteFill style={{ background: "radial-gradient(#fff,#ffb24d)", opacity: o, mixBlendMode: "screen" }} />;
};

export const AngelcoreMV: React.FC = () => (
  <AbsoluteFill style={{ background: "#05060a" }}>
    {/* Verse: macro hero-on-black, hard cut every 2 beats */}
    <Sequence from={beat(0)} durationInFrames={beat(2)}><Video src="/selects/key.mp4" /></Sequence>
    <Sequence from={beat(2)} durationInFrames={beat(2)}><Video src="/selects/eye.mp4" /></Sequence>
    <Sequence from={beat(4)} durationInFrames={beat(2)}><Video src="/selects/gear.mp4" /></Sequence>
    {/* Drop: crystalline bloom + flash on the one */}
    <Sequence from={beat(8)} durationInFrames={beat(16)}><Video src="/selects/crystalline.mp4" /></Sequence>
    <Sequence from={beat(8)} durationInFrames={beat(1)}><Bloom /></Sequence>
  </AbsoluteFill>
);
```
レンダリング: `npx remotion render src/index.ts AngelcoreMV out.mp4`。プロジェクトのセットアップ、オーディオトラックのバインド、レンダリングフラグについては `remotion-video-creation` を参照してください。

## Key Principles

1. **最初の生成の前にジャンルを決める。** 主ファミリーを一つとアクセントを一つ選びます。
2. **1 ショットにつきアクセントカラーは 1 つ。** 闇には金、光には虹色、赤は一度だけ。
3. **すべてのハードカットはビートに乗せる。** ビート計算を使い、テンポのあるセクションにトランジションは入れません。
4. **黒の上のヒーローマクロが署名の技。** これを極めてください。ヴァースはこれが支えます。
5. **10 個生成して 2 個残す。** 一貫性は、プロンプトを頑張ることではなく、却下することから生まれます。
6. **UI クロームをクロップする。** ステータスバー、キャプション、UI を最終フレームに残しません。
7. **テイストは最初に決め、最後に判断する。** 方向性を定め、すべてのカットでそれを守り抜きます。

## Related Skills

- `video-editing` — このスキルが土台とするメカニカルなパイプライン（FFmpeg、リフレーム、EDL、ポリッシュ）
- `remotion-video-creation` — プログラマブルなビート同期のコンポジションとレンダリング
- `fal-ai-media` — b-roll、トランジション SFX、ライザーを生成する
- `motion-foundations`, `motion-patterns`, `motion-advanced` — イージングとモーションのタイミング
- `videodb` — 大きな素材向けのサーバーサイドのスマートリフレームとインデックス化
- `content-engine` — プラットフォームネイティブの配信、カバー、キャプション
- `frontend-design-direction` — 同じ「まず方向性を決める」規律を UI に適用したもの
