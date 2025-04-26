// compress-images.js
// ローカルで実行する画像変換バッチ(「LINEで確実に表示できる形式」に一括変換)
// ✅ 目的:
//   - pngを、Cloudinary 等と同等のLINE上表示体系JPEGに変換
//   - 全ファイルBaseline JPEG/最小メタ/RGBに
//   - public_input/{images|carousel} → public/{images|carousel}へ
//   - public_input/{images|carousel}配下のpngは全部変換しちゃうから注意(他は無視)
// ✅ 画像変換の主な仕様（CDN級）
//  progressive: false ＝ Baseline JPEG（LINE互換）
//  chromaSubsampling: "4:4:4" ＝ 高品質維持
//  optimizeCoding: true ＝ 効率的なエンコーディング
//  flatten で透過PNG → 白背景に変換
// ✅ 前提の前提(Node.jsのバージョンを確認：最低14以上、できれば16以上)
// node -v
// ✅ 前提(sharpをインストールする)
// npm install sharp
// 確認方法
// node -e "require('sharp'); console.log('✅ sharp 読み込み成功！')"
// ✅ 実行方法
// node compress-images.js	      → 通常モード（normal）で変換
// node compress-images.js detail	→ 拡大モード（detail）で変換、ファイル名に_detailつく

//⚠️ Macユーザーがやるべき環境設定
//1. Node.js のインストール（Homebrew推奨）
//brew install node
//2. プロジェクトルートで sharp をインストール
//cd /path/to/project
//npm install sharp
//3.テスト( → 出力例：✅ sharp 読み込み成功！
//node -e "require('sharp'); console.log('✅ sharp 読み込み成功！')"
//▶️ 実行コマンド
//node compress-images.js
//🎁 おまけ：Mac用に .sh スクリプトを作ると便利
//例：run-compress.sh
//#!/bin/bash
//node compress-images.js
//bash
//chmod +x run-compress.sh
//./run-compress.sh


const path = require("path");

// NODE_PATHを動的に設定
process.env.NODE_PATH = path.resolve(__dirname, "functions", "node_modules");
require('module').Module._initPaths();

const sharp = require("sharp");
const fs = require("fs");

// --- ここ強化版 ---
const args = process.argv.slice(2);
let mode = "normal"; // デフォルト

if (args.length > 0) {
  if (args[0] === "detail") {
    mode = "detail";
  } else if (args[0] !== "normal") {
    console.log(`⚠️ 未知のモード "${args[0]}" が指定されました。normalモードで実行します。`);
  }
}
console.log(`🚀 compress-images.js 実行モード: ${mode}`);
// -----------------

// 処理対象ディレクトリ
const targets = [
  { input: "images", output: "images" },
  { input: "carousel", output: "carousel" }
];

// 全ターゲットを回して変換実行
for (const { input, output } of targets) {
  const inputDir = path.join(__dirname, "public_input", input); 
  const outputDir = path.join(__dirname, "public", output); 

  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  fs.readdir(inputDir, (err, files) => {
    if (err) {
      console.log(`📂 入力フォルダが見つかりませんでした（スキップします）: ${inputDir}`);
      return;
    }

    files.forEach((file) => {
      const ext = path.extname(file).toLowerCase();
      if (ext !== ".png") return; // 対象はPNGのみ

      const inputPath = path.join(inputDir, file);

      // --- ファイル名に_detailを付けるか切り替え ---
      const baseName = path.parse(file).name;
      const outputFileName = mode === "detail" ? `${baseName}_detail.jpg` : `${baseName}.jpg`;
      // -------------------------------------------------

      const outputPath = path.join(outputDir, outputFileName);

      const sharpInstance = sharp(inputPath)
        .flatten({ background: { r: 255, g: 255, b: 255 } }); // 透明を白背景に

      if (mode === "normal") {
        sharpInstance
          .resize({ fit: "inside", withoutEnlargement: true })
          .jpeg({
            quality: 85,              // 適度な質でサイズ抑制
            progressive: false,       // Baseline JPEG
            optimizeCoding: true,     // ハフマン符号化(JPEGへのデータ圧縮方法)をする。少し時間はかかるけどファイルが更に小さくなる
            chromaSubsampling: "4:4:4" // 色データ保持
          });
      } else if (mode === "detail") {
        sharpInstance
          .resize({ width: 1920, withoutEnlargement: true }) // 横幅1920pxまで広げる
          .jpeg({
            quality: 90,              // 少し高品質
            progressive: false,       
            optimizeCoding: true,     
            chromaSubsampling: "4:4:4"
          });
      }

      sharpInstance
        .toFile(outputPath)
        .then(() => {
          console.log(`✅ ${input}/${file} → ${output}/${outputFileName}`);
        })
        .catch((err) => {
          console.error(`❌ ${input}/${file} の変換に失敗しました:`, err.message);
        });
    });
  });
}