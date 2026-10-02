# foundry-handson-workshop 向け Copilot 指示

このリポジトリには、Microsoft Foundry 初心者向けハンズオンワークショップの資料が含まれています。日本語のガイド、共有 Azure 環境向けの Bicep と Bash、Lab 3 の Python サンプル、ナレッジベース用の架空企業ドキュメントがあります。

## 言語と文体

- 解説とドキュメントは日本語で書いてください。ユーザーから求められた場合に限り、英語を使用してください。
- Markdown のコードブロック内も含め、コード、コードコメント、識別子、文字列、ログは英語で記述してください。
- 事実に基づき、簡潔かつ具体的に書いてください。表、箇条書き、手順形式を優先してください。3つのガイド全体で用語と文末表現を統一してください。
- リポジトリ内のリンクには相対パスを使用してください。ファイルを移動または改名した場合は、そのファイルへのリンクをすべて更新し、リンク先が存在することを確認してください。

## リポジトリの構成

| パス | 役割 |
|---|---|
| `instructor-guide.md` | 講師向けガイド（概要、チェックリスト、タイムテーブル、回答、トラブルシューティング） |
| `setup-guide.md` | ワークショップ前の Azure CLI 手順。§1 に Copilot 向けのルールがあるため、記載されたコマンドを実行する際は必ず従ってください |
| `lab-guide.md` | 参加者向けガイド（Lab 0～4、任意の Teams 公開）。必要な権限は `setup-guide.md` の §2 にまとめ、ここからはリンクだけ置く |
| `infra/` | `main.bicep`、`main.bicepparam`、`scripts/`（ナレッジベースのセットアップ、プロジェクトのロール割り当て） |
| `lab3/` | Lab 3 の Python サンプル。同じコードが `lab-guide.md` の §4 にも記載されているため、両方を同期してください |
| `sample-docs/` | 架空の Contoso ドキュメント。`instructor-guide.md` の §6 の回答と `lab-guide.md` の §3.3 の質問は、この内容に基づいています |

## Azure の操作

- `setup-guide.md` のコマンドを実行する前に、§1 の表にある値をユーザーに1項目ずつ確認してください。`HANDOFF.md` の §5 に記載された過去の値は、確認せずに再利用しないでください。
- デプロイ、ロールの付与、リソースの削除、Foundry リソースのパージを行う前に、ユーザーに確認してください。
- 実環境で変更を検証した場合は、日付と検証結果を `HANDOFF.md` の §5 に記録してください。`HANDOFF.md` はコミットの成果物にしないため、ガイドからはリンクしないでください。
- 価格、クォータ、モデルのバージョン、ポータル画面の名称は頻繁に変わります。これらを記載する場合は短い注記と公式ドキュメントへのリンクを添え、ガイドを更新する前に Microsoft Learn で確認してください。
- `infra/main.bicep` または `infra/main.bicepparam` を変更した場合は、`az bicep build --file infra/main.bicep` と `az bicep build-params --file infra/main.bicepparam` を実行してください。スクリプトを変更した場合は、`bash -n infra/scripts/*.sh` を実行してください。

## Python パッケージ

- `lab-guide.md` の参加者向け手順は、受講者の Azure Cloud Shell で実行します。`pip install --user` の形式を維持し、`instructor-guide.md` に記載された受講者側のパッケージフィード要件に従ってください。
