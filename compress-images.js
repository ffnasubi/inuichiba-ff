// compress-images.js
// ローカルで実行する画像変換バッチ(「LINEで確実に表示できる形式」に一括変換)
// ✅ 目的:
//   - pngを、Cloudinary 等と同等のLINE上表示体系JPEGに変換
//   - 全ファイルBaseline JPEG/最小メタ/RGBに
//   - public_input/{images|carousel} → 
//      public/{images|carousel} と public_input/assts-hosting/{images|carousel}へ
//   - public_input/{images|carousel}配下のpngは全部変換しちゃうから注意(png以外は無視)
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
  const baseInputDir = path.join(__dirname, "public_input", input);
  const outputDir1 = path.join(__dirname, "public", output);       // ① public 配下
  const outputDir2 = path.join(__dirname, "public_input", "assets-hosting", output); // ② assets-hosting 配下

  // 出力ディレクトリの作成
  [outputDir1, outputDir2].forEach((dir) => {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  });

  fs.readdir(baseInputDir, (err, files) => {
    if (err) {
      console.log(`📂 入力フォルダが見つかりませんでした（スキップします）: ${baseInputDir}`);
      console.log(`🔍 エラー内容: ${err.message}`);
      return;
    }

    files = files.filter(f => f.toLowerCase().endsWith(".png")).sort();  // ✅ ファイル名順に並べる

    files.forEach((file) => {
      const ext = path.extname(file).toLowerCase();
      if (ext !== ".png") return; // 対象はPNGのみ

      const inputPath = path.join(baseInputDir, file);

      // --- ファイル名に_detailを付けるか切り替え ---
      const baseName = path.parse(file).name;
      const outputFileName = mode === "detail" ? `${baseName}_detail.jpg` : `${baseName}.jpg`;
      // -------------------------------------------------

      const outputPaths = [
        path.join(outputDir1, outputFileName),
        path.join(outputDir2, outputFileName)
      ];

      // 共通のsharp処理
      // 透明を白背景に
      const baseSharp = sharp(inputPath).flatten({ background: { r: 255, g: 255, b: 255 } });

      if (mode === "normal") {
        baseSharp
//        .resize({ width: 1200, withoutEnlargement: true })    // ★ 横幅を強制的に制限（1920→1200など）
          .resize({ fit: "inside", withoutEnlargement: true })  // ファイルサイズが大きいなら避けて上の方法でどうぞ
          .jpeg({
            quality: 75,              // 適度な質でサイズ抑制(元は85だが大きいときは65迄さげてOK)
            progressive: false,       // Baseline JPEG
            optimizeCoding: true,     // ハフマン符号化(JPEGへのデータ圧縮方法)をする。少し時間はかかるけどファイルが更に小さくなる
            chromaSubsampling: "4:4:4" // 色データ保持(LINE表示品質向上)
          });
      } else if (mode === "detail") {
        baseSharp
          .resize({ width: 1920, withoutEnlargement: true }) // 横幅1920pxまで広げる
          .jpeg({
            quality: 90,              // 少し高品質
            progressive: false,       
            optimizeCoding: true,     
            chromaSubsampling: "4:4:4"
          });
      }

      // 出力先それぞれに保存
      outputPaths.forEach((outputPath) => {
        baseSharp.clone()         // 同じ画像処理を複数ファイルに安全に出力する
          .toFile(outputPath)
          .then(() => {
            // 元ファイルサイズ取得
            const inputSize = fs.statSync(inputPath).size;
            // 変換後ファイルサイズ取得
            fs.stat(outputPath, (err, stats) => {
              if (!err) {
                const outputSize = stats.size;
                const rate = ((outputSize / inputSize) * 100).toFixed(1);
                const sizeKB = (outputSize / 1024).toFixed(1);
                console.log(`✅ ${input}/${file} → ${outputPath}（${sizeKB} KB, 圧縮率 ${rate}%）`);
              } else {
                console.log(`✅ ${input}/${file} → ${outputPath}（圧縮率計算失敗）`);
              }
            })
          })
          .catch((err) => {
            console.error(`❌ 変換失敗: ${outputPath} - ${err.message}`);
          });
      });
    });
  });
}
