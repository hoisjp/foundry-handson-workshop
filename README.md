# Microsoft Foundry 入門ハンズオンワークショップ

Microsoft Foundry を初めて使う方向けの 90 分のハンズオンです。題材は、架空企業「コントソ株式会社」の社内規程と FAQ に答える社内ヘルプデスクエージェントです。講師が事前に構築した共通 Azure 環境（1 つの Foundry リソース）を、参加者全員で共有します。

| Lab | 内容 |
|---|---|
| Lab 0 | 講師が事前に作成した自分のプロジェクトを開く |
| Lab 1 | モデルをプレイグラウンドで試す |
| Lab 2 | Foundry IQ のナレッジベースを接続したエージェントを作る |
| Lab 3 | Python SDK から自分のエージェントを呼び出す |
| Lab 4 | トレースでエージェントの内部動作を確認する |
| 追加演習 | エージェントを Microsoft Teams／Microsoft 365 Copilot に公開する（任意） |

## ドキュメント

| ファイル | 対象 | 内容 |
|---|---|---|
| [instructor-guide.md](./instructor-guide.md) | 講師 | 概要、環境構成、事前準備のチェックリスト、タイムテーブル、正解例、トラブルシュート |
| [setup-guide.md](./setup-guide.md) | 講師・環境構築者 | 事前準備の Azure CLI 手順（必要な権限の一覧、前提条件の確認、デプロイ、ナレッジベース構築、RBAC の確認・付与、プロジェクト追加時のロール付与、後片付け） |
| [lab-guide.md](./lab-guide.md) | 参加者 | 当日の手順書（Lab 0〜4、追加演習） |

## フォルダ構成

| パス | 内容 |
|---|---|
| [infra/main.bicep](./infra/main.bicep) | 共通環境（Foundry リソース、モデルデプロイ 4 種、共有プロジェクト、参加者用プロジェクト、Azure AI Search、Storage、Log Analytics、Application Insights、ロール割り当て） |
| [infra/main.bicepparam](./infra/main.bicepparam) | パラメーター例。[setup-guide.md](./setup-guide.md) ではパラメーターをコマンドラインで渡すため、編集は不要 |
| [infra/scripts/setup-knowledge-base.sh](./infra/scripts/setup-knowledge-base.sh) | 架空社内文書のアップロードと、Foundry IQ のナレッジソース・ナレッジベースの作成、取得テスト |
| [infra/scripts/grant-project-access.sh](./infra/scripts/grant-project-access.sh) | デプロイ後に追加したプロジェクトのマネージド ID にロールを付与する（事前作成したプロジェクトは `main.bicep` で付与済み） |
| [lab3/](./lab3/) | Lab 3 の Python コード（手順書にも同じコードを掲載） |
| [sample-docs/](./sample-docs/) | ナレッジベース用の架空社内文書（テレワーク規程、経費精算規程、休暇規程、IT ヘルプデスク FAQ） |

## はじめに

1. [setup-guide.md](./setup-guide.md) に沿って、ワークショップの 3〜5 日前に共通環境を構築します。コマンドはこのリポジトリのルートで実行します。
2. [instructor-guide.md](./instructor-guide.md) のリハーサル項目を、参加者と同じ権限のテストユーザーで確認します。
3. 当日は [lab-guide.md](./lab-guide.md) を参加者に配布します。

> **注意:** Foundry のポータル UI、ロール名、API、モデル、クォータは頻繁に変わります。Foundry IQ（ナレッジベース）と一部の機能はプレビューです。Azure AI Search（Basic）はデプロイしている間ずっと課金されるため、ワークショップ後は [setup-guide.md](./setup-guide.md) の後片付けを実行してください。最新の価格は [Azure の価格](https://azure.microsoft.com/pricing/) で確認してください。

## ライセンス

[MIT License](./LICENSE)
