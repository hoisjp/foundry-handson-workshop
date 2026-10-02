# ワークショップ事前準備 CLI 手順（デプロイ・ナレッジベース・RBAC、2026-10-01）

Microsoft Foundry 入門ハンズオンの共通環境を、講師が事前に準備するための Azure CLI 手順です。次の作業を順に行います。

| # | 作業 | 実行タイミング | 使用するもの |
|---|---|---|---|
| 1 | 前提条件の確認（権限、リソースプロバイダー、モデルのクォータ、参加者グループ） | 事前 | Azure CLI（§4） |
| 2 | 共通リソースのデプロイ（Foundry リソース、モデル、共有プロジェクト、参加者用プロジェクト、Azure AI Search、Storage、Log Analytics、Application Insights、ロール割り当て） | 事前 | [main.bicep](./infra/main.bicep)（§5） |
| 3 | ナレッジベースの構築 | デプロイ後 | [setup-knowledge-base.sh](./infra/scripts/setup-knowledge-base.sh)（§6） |
| 4 | RBAC の確認と不足分の付与（参加者用プロジェクトの MI、Teams Publish 用を含む） | デプロイ後 | Azure CLI（§7〜§9） |
| 5 | 後から追加したプロジェクトの MI へのロール付与 | プロジェクトを追加したときだけ | [grant-project-access.sh](./infra/scripts/grant-project-access.sh)（§10） |
| 6 | 後片付け | ワークショップ後 | Azure CLI（§11） |

参加者用プロジェクト（`proj-01`〜`proj-NN`）は §5 のデプロイで事前に作成し、各プロジェクトのマネージド ID（MI）へのロール割り当ても同時に行います。当日に講師がロールを付与する作業はありません。参加者は Lab 0 で、講師から割り当てられた番号のプロジェクトを開きます。

対象は [§2.1](#21-このワークショップに必要な-azure-rbac) の Azure RBAC と、[§2.2](#22-foundry-agent-を-microsoft-teams-に-publish-するための権限) のうち Azure 側の設定（Azure RBAC と `Microsoft.BotService` の登録）です。参加者グループの作成、**People in your organization** での公開承認、Teams のカスタムアプリポリシーは Entra／Microsoft 365／Teams 管理センターで行うため、このファイルの対象外です。

> **コストの注意:** Azure AI Search（Basic）はデプロイ中ずっと課金されます（2026-10-01 時点の Central US の Retail Prices API で 1 時間 $0.101、1 日約 $2.4）。モデル（GlobalStandard）は使用量に応じて課金されます。エージェント検索（ナレッジベースの取得）は月間の無料枠を超えると従量課金になります。無料枠を使い切って止まらないように、`main.bicep` で `knowledgeRetrieval` を `standard` に設定しています（[エージェント検索の課金](https://learn.microsoft.com/azure/search/agentic-retrieval-how-to-enable-disable)）。最新の価格は [Azure AI Search の価格](https://azure.microsoft.com/pricing/details/search/) と [Azure OpenAI の価格](https://azure.microsoft.com/pricing/details/cognitive-services/openai-service/) を確認してください。
>
> Basic より安い層は採用していません。Free はマネージド ID に対応しておらず、Central US ではエージェント検索も使えません。Serverless Developer はプレビューで、マネージド ID と Foundry IQ の対応を確認できていません（[層の選択](https://learn.microsoft.com/azure/search/search-sku-tier)、[リージョン対応](https://learn.microsoft.com/azure/search/search-region-support)）。

## 1. 実行前の確認ルール（Copilot／実行者向け）

> **Copilot への指示:** このファイルのコマンドを実行・再実行するときは、以下を毎回守ること。
>
> 1. 実行前に、下表の項目を **1 項目ずつ `ask_user` でユーザーに確認する**。過去の検証値や現在の `az account show` の値を、確認なしに既定値として使わない（選択肢の候補として提示するのはよい）。
> 2. §4 の前提条件の結果を示し、**デプロイを実行してよいか確認してから** §5 を実行する。既存のリソースグループにデプロイする場合は、既存リソースへの影響も説明する。
> 3. §8「現状確認」の結果を示し、**付与を実行してよいか確認してから** §9「付与」を実行する。付与後に §8.2 を再実行し、全行が `OK` になったことを確認する。
> 4. §11 の後片付け（リソースグループの削除と Foundry リソースの消去）は、ユーザーの明示的な指示がある場合だけ実行する。

| 確認項目 | 変数 | 確認のしかた |
|---|---|---|
| サブスクリプション | `SUBSCRIPTION_ID` | `az account show` の結果を候補として提示する |
| リソースグループ | `RG` | 新規作成する名前、または `az group list` の既存候補を提示する |
| リソース名の接頭辞とリージョン | `PREFIX`、`LOCATION`、`SEARCH_LOCATION` | 接頭辞は英小文字と数字で 3〜12 文字。Bicep の既定は `eastus2`、Search は `centralus`（East US 2 は Search を新規作成できない場合がある） |
| 参加者グループ | `PARTICIPANT_GROUP_ID` | Entra ID **セキュリティグループ**のオブジェクト ID（Microsoft 365 グループは使わない）。§4 で `securityEnabled` が `true` であることを確認する。不明であれば実際の環境を確認して実行者に確認する。 |
| 参加者の権限モード | `PARTICIPANT_ACCESS_MODE` | `ownProject`（参加者ごとのプロジェクトを使う、`Foundry Owner`）または `sharedProject`（共有プロジェクトを使う、`Foundry User`） |
| 参加者用プロジェクトの数 | `PARTICIPANT_PROJECT_COUNT` | 参加者数に予備（2〜3 個）を足した数。`proj-01` から連番で作成する。`sharedProject` の場合は `0`。1 つの Foundry リソースに作れるプロジェクトは 250 個まで（[制限](https://learn.microsoft.com/azure/foundry/foundry-models/quotas-limits)） |
| 講師・環境構築者 | `INSTRUCTOR_ID`、`INSTRUCTOR_TYPE` | オブジェクト ID と種別（`User`／`Group`／`ServicePrincipal`）。サインイン中のユーザーを候補として提示する |
| Teams Publish 用の Azure 設定 | `INCLUDE_TEAMS_PUBLISH` | 追加演習で Foundry Agent を Teams に Publish する場合のみ `true`。Publish 先のリソースグループは `RG` と同じ前提 |
| デプロイ・付与・後片付けの実行可否 | — | §4、§8 の結果を示した後に、それぞれ確認する |

## 2. 必要な権限

参加者用手順書 [lab-guide.md](./lab-guide.md) からは、この章にリンクしています。§2.1 と §2.2 は目的別の一覧、§2.3 は §7〜§9 のコマンドが確認・付与するロールの一覧です。

### 2.1 このワークショップに必要な Azure RBAC

以下は、参加者用手順書をそのまま実施する場合のロールです。`Foundry User` は Foundry リソース／プロジェクトの読み取り権限を含むため、同じスコープの `Reader` は重ねて付与しません。ロール名は 2026 年に変更されており、画面によっては旧名（`Azure AI User`、`Azure AI Owner` など）が表示される場合があります。ロール ID と主要な権限は変更されていません。

#### 参加者グループ

| Azure ロール | スコープ | 使用する Lab | 目的 |
|---|---|---|---|
| `Foundry Owner` | 共通 Foundry リソース | Lab 0〜4 | 事前作成した自分のプロジェクトで、モデル、エージェント、SDK、トレースを利用する。Lab 2 ではプロジェクトの接続（Azure AI Search、ナレッジベース）を作成する。`Foundry User` と Foundry リソースの `Reader` を包含する |
| `Reader` | ワークショップのリソースグループ | Lab 0、4 | Azure／Foundry ポータルで共通リソースと監視リソースを参照する |
| `Search Index Data Reader` | 共通 Azure AI Search | Lab 2 | 共有ナレッジベースの検索データを読み取る |
| `Log Analytics Reader` | 共通 Log Analytics ワークスペース | Lab 4 | Application Insights に保存されたトレースを照会する |

> **参加者のロールを下げられない理由:** プロジェクトを事前作成するため、参加者はプロジェクトを作成しません。ただし、Lab 2 の **Connect to Foundry IQ** はプロジェクトの接続を作成します（`Microsoft.CognitiveServices/accounts/projects/connections/write`）。`Foundry User` にはこの権限がないため、参加者のロールは `Foundry User` に下げられません。`Foundry Project Manager` は接続を作成でき、モデルデプロイは変更できませんが、このワークショップでは未検証です。`Foundry Owner` では参加者が新しいプロジェクトを作成したり、他の参加者のプロジェクトを開いたりできます。当日に「割り当てられたプロジェクト以外を使わない」と案内してください。

#### サービスのマネージド ID

| 対象 | Azure ロール | スコープ | 目的 |
|---|---|---|---|
| 各 Foundry プロジェクトのマネージド ID | `Foundry User` | 共通 Foundry リソース | プロジェクトからモデルとエージェントを実行する |
| 各 Foundry プロジェクトのマネージド ID | `Search Index Data Reader` | 共通 Azure AI Search | エージェントから共有ナレッジベースを検索する |
| Azure AI Search のマネージド ID | `Storage Blob Data Reader` | 文書を置く Storage Account | ナレッジソースの文書を読み取る |
| Azure AI Search のマネージド ID | `Cognitive Services User` | 共通 Foundry リソース | インデックス作成とクエリ計画で埋め込み／チャットモデルを呼び出す |

共有プロジェクトと参加者用プロジェクトのマネージド ID には、§5 のデプロイでロールを割り当てます。デプロイ後にプロジェクトを追加した場合だけ、§10 で割り当てます。Azure RBAC の反映には数分かかる場合があります。

#### 講師・環境構築者

| Azure ロール | スコープ | 目的 |
|---|---|---|
| `Foundry Owner` | 共通 Foundry リソース | モデル、プロジェクト、接続、エージェントを準備・管理する |
| `Search Service Contributor` | 共通 Azure AI Search | インデックス、データソース、インデクサー等を管理する |
| `Search Index Data Contributor` | 共通 Azure AI Search | 検索インデックスのデータを作成・更新する |
| `Storage Blob Data Contributor` | 文書を置く Storage Account | 架空社内文書をアップロード・更新する |
| `Contributor` | ワークショップのリソースグループ | Bicep で Azure リソースを作成・更新する |
| `Role Based Access Control Administrator` または `Owner` | ワークショップのリソースグループ | Bicep と講師スクリプトで上記のロール割り当てを作成する |

参照: [Role-based access control for Microsoft Foundry](https://learn.microsoft.com/azure/foundry/concepts/rbac-foundry)、[Set up tracing in Microsoft Foundry](https://learn.microsoft.com/azure/foundry/observability/how-to/trace-agent-setup)、[Azure AI Search のロール](https://learn.microsoft.com/azure/search/search-security-rbac)

### 2.2 Foundry Agent を Microsoft Teams に Publish するための権限

Teams への Publish はこのワークショップの必須 Lab には含めません。追加演習として実施する場合は、Azure RBAC と Microsoft 365 側のポリシー／管理者承認を分けて準備します。公開と確認の手順は [参加者用手順書 第 7 章](./lab-guide.md#7-追加演習-エージェントを-teams-に公開する任意10-分) を参照してください。

#### Publish するユーザー

| 種別 | 必要な権限 | スコープ／条件 |
|---|---|---|
| Azure RBAC | `Foundry Project Manager` 以上 | Foundry リソース。Agent Application の Publish に必要な最小ロール。現在の構成で参加者に付与する `Foundry Owner` はこの権限を包含する |
| Azure RBAC | `Azure Bot Service Contributor Role` | Publish 先のリソースグループ。Azure Bot Service の作成（`Microsoft.BotService/botServices/write`）と Teams／Microsoft 365 チャネル設定（`Microsoft.BotService/botServices/channels/write`）に必要。Foundry のロールでは代替できない |
| サブスクリプション設定 | `Microsoft.BotService` リソースプロバイダーが登録済み | 未登録の場合は、登録権限を持つサブスクリプション管理者が事前に登録する |
| Microsoft Teams ポリシー | カスタムアプリのアップロードが許可されていること | マニフェスト ZIP をダウンロードして手動でサイドロードする場合のみ。Teams 管理センターの **Upload custom apps** ポリシーで制御される |

> **公式ドキュメント間の表現差:** Teams 公開手順の前提条件には「プロジェクトの `Foundry User`」と記載されていますが、Foundry RBAC の権限表では Agent Application の Publish に `Foundry Project Manager` 以上が必要です。新規 Publish を確実に通す構成として、本手順書では `Foundry Project Manager` を最小ロールとして扱います。既存の Agent Application を呼び出すだけの利用者には `Foundry Agent Consumer` を使用します。

#### 公開範囲ごとの Microsoft 365 側の要件

| Publish の範囲 | 追加要件 |
|---|---|
| **Just you** | Microsoft 365 管理者の承認は不要。Teams チャットで共有された利用者には、少なくとも対象エージェント／プロジェクトの `Foundry Agent Consumer`（開発も行う場合は `Foundry User`）を付与する |
| **People in your organization** | Microsoft 365 管理センターで `AI Administrator` または `Global Administrator` が申請を承認し、利用者／グループへの公開範囲を設定する。最小権限は `AI Administrator` |
| マニフェスト ZIP の手動サイドロード | 対象ユーザーに Teams の **Upload custom apps** が許可されている必要がある。組織のアプリカタログへ公開する場合は Teams／Microsoft 365 管理者による審査・公開が必要 |

Publish 後の Agent Application はプロジェクトとは別の ID を使用します。ナレッジベースなど外部 Azure リソースへマネージド ID で接続するエージェントでは、Publish 後の ID にも必要なデータプレーン権限（このワークショップでは Azure AI Search の `Search Index Data Reader`）を付与してから Teams でテストしてください。

参照: [Publish agents to Microsoft Copilot and Microsoft Teams](https://learn.microsoft.com/azure/foundry/agents/how-to/publish-copilot)、[Foundry hosted agent permissions](https://learn.microsoft.com/azure/foundry/agents/concepts/hosted-agent-permissions)、[Microsoft 365 の Agent 管理ロール](https://learn.microsoft.com/microsoft-365/admin/manage/agent-roles-perms)、[Teams のカスタムアプリ設定](https://learn.microsoft.com/microsoftteams/teams-custom-app-policies-and-settings)

### 2.3 確認・付与の対象ロール

ロール名は 2026 年の Foundry ロール名変更後の表示名です。コマンドはロール定義 ID で判定するため、旧名が表示される環境でも動作します。「Bicep」列が ✓ のロールは §5 のデプロイで作成され、それ以外は §9 または §10 で付与します。

| 区分 | プリンシパル | ロール | ロール定義 ID | スコープ | Bicep |
|---|---|---|---|---|---|
| 参加者 | 参加者グループ | `Foundry Owner`（`sharedProject` 時は `Foundry User`） | `c883944f-8b7b-4483-af10-35834be79c4a`（`53ca6127-db72-4b80-b1b0-d745d6d5456d`） | Foundry リソース | ✓ |
| 参加者 | 参加者グループ | `Reader` | `acdd72a7-3385-48ef-bd42-f606fba81ae7` | リソースグループ | ✓ |
| 参加者 | 参加者グループ | `Search Index Data Reader` | `1407120a-92aa-4202-b7e9-c0e197c71c8f` | Azure AI Search | ✓ |
| 参加者 | 参加者グループ | `Log Analytics Reader` | `73c42c96-874c-492b-b04d-ab87d138a893` | Log Analytics ワークスペース | ✓ |
| マネージド ID | 各プロジェクトの MI | `Foundry User` | `53ca6127-db72-4b80-b1b0-d745d6d5456d` | Foundry リソース | ✓（後から追加したプロジェクトを除く） |
| マネージド ID | 各プロジェクトの MI | `Search Index Data Reader` | `1407120a-92aa-4202-b7e9-c0e197c71c8f` | Azure AI Search | ✓（後から追加したプロジェクトを除く） |
| マネージド ID | Search の MI | `Storage Blob Data Reader` | `2a2b9908-6ea1-4ae2-8e65-a410df84e7d1` | Storage Account | ✓ |
| マネージド ID | Search の MI | `Cognitive Services User` | `a97b65f3-24c7-4388-baec-2e87135dc908` | Foundry リソース | ✓ |
| 講師 | 講師 | `Foundry Owner` | `c883944f-8b7b-4483-af10-35834be79c4a` | Foundry リソース | ✓ |
| 講師 | 講師 | `Search Service Contributor` | `7ca78c08-252a-4471-8644-bb5ff32d4ba0` | Azure AI Search | ✓ |
| 講師 | 講師 | `Search Index Data Contributor` | `8ebe5a00-799e-43f5-93ac-243d3dce84a7` | Azure AI Search | ✓ |
| 講師 | 講師 | `Storage Blob Data Contributor` | `ba92f5b4-2d11-453d-a403-e96b0029c9fe` | Storage Account | ✓ |
| 講師 | 講師 | `Contributor`（`Owner` でも可） | `b24988ac-6180-42a0-ab88-20f7382dd24c` | リソースグループ | — |
| 講師 | 講師 | `Role Based Access Control Administrator`（`Owner` でも可） | `f58310d9-a9f6-439a-9e8d-f62e7b41a168` | リソースグループ | — |
| Teams（任意） | 参加者グループ | `Foundry Project Manager`（`Foundry Owner` でも可） | `eadc314b-1a2d-4efa-be10-5d325db5065e` | Foundry リソース | — |
| Teams（任意） | 参加者グループ | `Azure Bot Service Contributor Role`（`Contributor`／`Owner` でも可） | `9fc6112f-f48e-4e27-8b09-72a5c94e4ae9` | リソースグループ | — |
| Teams（任意） | 講師 | `Foundry Project Manager`（`Foundry Owner` でも可） | `eadc314b-1a2d-4efa-be10-5d325db5065e` | Foundry リソース | — |
| Teams（任意） | 講師 | `Azure Bot Service Contributor Role`（`Contributor`／`Owner` でも可） | `9fc6112f-f48e-4e27-8b09-72a5c94e4ae9` | リソースグループ | — |

講師の `Contributor` と `Role Based Access Control Administrator` は、§5 のデプロイと §9 の付与を行うための前提です。リソースグループを新規作成する場合は、サブスクリプション以上のスコープで `Owner`、または `Contributor` と `Role Based Access Control Administrator`（または `User Access Administrator`）が必要です。

Teams（任意）の行は `INCLUDE_TEAMS_PUBLISH=true` の場合だけ確認・付与します。あわせて `Microsoft.BotService` リソースプロバイダーを登録します。Publish で作られるエージェント ID は Foundry プロジェクトへの暗黙のアクセス権を持つため、ツールを使わない Prompt Agent では追加のロールは不要です。

判定ルール:

- 対象スコープまたは親スコープ（リソースグループ、サブスクリプション、管理グループ）への割り当てを「付与済み」とみなす。親スコープの場合は `OK(inherited)` と表示する。
- 講師の `Contributor` と `Role Based Access Control Administrator` は、`Owner`（`8e3af657-a8ff-443c-a75c-2fe8c4bcb635`）があれば満たしているとみなし、`OK(alt)` と表示する。
- `Foundry Project Manager` は `Foundry Owner` があれば、`Azure Bot Service Contributor Role` は `Contributor` または `Owner` があれば満たしているとみなし、`OK(alt)` と表示する。§9 では作成直前に再判定するため、同じ実行で付与した `Foundry Owner` と重複して `Foundry Project Manager` を作成しない。
- グループ経由の割り当て（講師が所属するグループへの割り当て）は判定しない。必要なら §8.1 の一覧で目視確認する。
- プロジェクトの MI は、確認時点で Foundry リソース配下にある全プロジェクト（共有プロジェクト、参加者用プロジェクト、後から追加したプロジェクト）を対象にする。プロジェクトを追加した場合は §10 で再確認する。

## 3. 変数の設定

bash で実行します。zsh の場合は先に `bash` を起動してください。§3〜§11 は、リポジトリのルートで同じシェルを使って続けて実行します。

値はすべて §1 のルールに従ってユーザーに確認してから設定します。

```bash
export SUBSCRIPTION_ID="<subscription-id>"
export RG="<resource-group>"
export PREFIX="<prefix>"                         # 3-12 lowercase letters and digits
export LOCATION="eastus2"
export SEARCH_LOCATION="centralus"
export PARTICIPANT_GROUP_ID="<participants-group-object-id>"
export PARTICIPANT_ACCESS_MODE="ownProject"      # ownProject | sharedProject
export PARTICIPANT_PROJECT_COUNT="32"            # participants + spares; 0 for sharedProject
export INSTRUCTOR_ID="<instructor-object-id>"
export INSTRUCTOR_TYPE="User"                    # User | Group | ServicePrincipal
export INCLUDE_TEAMS_PUBLISH="false"             # true when participants publish agents to Teams

# Leave empty to auto-detect in §7. Set when the resource group has more than one resource of a type.
export FOUNDRY_NAME="" SEARCH_NAME="" STORAGE_NAME="" LAW_NAME=""

export REPO_ROOT="$(git rev-parse --show-toplevel)"
export INFRA_DIR="$REPO_ROOT/infra"
export RBAC_WORKDIR="$(mktemp -d)"
az account set --subscription "$SUBSCRIPTION_ID"
az account show --query "{subscription:name, subscriptionId:id, user:user.name}" -o table
```

サインイン中のユーザーを講師にする場合は、次で `INSTRUCTOR_ID` を取得できます。

```bash
az ad signed-in-user show --query "{id:id, upn:userPrincipalName}" -o table
```

## 4. 前提条件を確認する

参加者グループがセキュリティグループであること、必要なリソースプロバイダーが登録済みであること、モデルのクォータに空きがあることを確認します。未登録のリソースプロバイダーは登録します（サブスクリプションの `Contributor` 以上が必要）。

```bash
az ad group show --group "$PARTICIPANT_GROUP_ID" \
  --query "{participantsGroup:displayName, securityEnabled:securityEnabled}" -o table

providers="Microsoft.CognitiveServices Microsoft.Search Microsoft.Storage Microsoft.OperationalInsights Microsoft.Insights"
[[ "$INCLUDE_TEAMS_PUBLISH" == "true" ]] && providers="$providers Microsoft.BotService"
for ns in $providers; do
  state="$(az provider show --namespace "$ns" --query registrationState -o tsv)"
  if [[ "$state" != "Registered" ]]; then
    az provider register --namespace "$ns" --wait
    state="$(az provider show --namespace "$ns" --query registrationState -o tsv)"
  fi
  echo "$ns: $state"
done

# Required capacity (thousands of TPM) from main.bicep, keyed by the quota name.
printf '%s\n' "gpt-5.4-mini 300" "gpt4.1-mini 100" "gpt-5-mini 100" "text-embedding-3-large 100" |
while read -r model required; do
  az cognitiveservices usage list -l "$LOCATION" \
    --query "[?name.value=='OpenAI.GlobalStandard.$model'].[currentValue, limit]" -o tsv |
  while IFS=$'\t' read -r current limit; do
    available="$(python3 -c "print(int(float('$limit') - float('$current')))")"
    status="OK"; (( available < required )) && status="INSUFFICIENT"
    echo "$status  $model: required=$required, available=$available (limit=$limit)"
  done
done
```

`securityEnabled` が `True` で、すべてのリソースプロバイダーが `Registered`、すべてのモデルが `OK` であれば次へ進みます。クォータが不足する場合は、`main.bicep` の `modelDeployments` の `capacity` を下げるか、[クォータの引き上げ](https://learn.microsoft.com/azure/foundry/openai/how-to/quota)を申請します。クォータの値はサブスクリプションとリージョンごとに変わるため、毎回確認してください。

## 5. 共通リソースをデプロイする

[main.bicep](./infra/main.bicep) をそのまま使います。パラメーターはコマンドラインで渡すため、[main.bicepparam](./infra/main.bicepparam) は編集しません。デプロイ名は、後続のスクリプトが既定で参照する `main` にします。

参加者用プロジェクト `proj-01`〜`proj-NN`（`NN` は `PARTICIPANT_PROJECT_COUNT`）と、各プロジェクトの MI へのロール割り当て（`Foundry User`、`Search Index Data Reader`）も、このデプロイで作成します。プロジェクトはモデルのデプロイ後に 1 つずつ作成するため、プロジェクトの数に応じてデプロイ時間が長くなります（プロジェクトなしで約 11 分。プロジェクトを含めた時間は未計測）。

```bash
PROJECT_NAMES_JSON="$(python3 -c 'import json, sys; print(json.dumps(["proj-%02d" % i for i in range(1, int(sys.argv[1]) + 1)]))' "$PARTICIPANT_PROJECT_COUNT")"
echo "$PROJECT_NAMES_JSON"

az group create -n "$RG" -l "$LOCATION" --tags workload=foundry-handson-workshop -o none

az deployment group create -g "$RG" -n main \
  --template-file "$INFRA_DIR/main.bicep" \
  --parameters prefix="$PREFIX" location="$LOCATION" searchLocation="$SEARCH_LOCATION" \
    participantsGroupObjectId="$PARTICIPANT_GROUP_ID" \
    instructorPrincipalId="$INSTRUCTOR_ID" instructorPrincipalType="$INSTRUCTOR_TYPE" \
    participantAccessMode="$PARTICIPANT_ACCESS_MODE" \
    participantProjectNames="$PROJECT_NAMES_JSON" \
  --query "{state:properties.provisioningState, duration:properties.duration}" -o table

az deployment group show -g "$RG" -n main --query "properties.outputs" -o json \
  | python3 -c 'import json, sys; [print(k.ljust(24), v["value"]) for k, v in json.load(sys.stdin).items() if k != "participantProjects"]'
```

参加者用プロジェクトの一覧を表示します。当日の割り当て表（参加者とプロジェクト名の対応）の作成に使います。

```bash
az deployment group show -g "$RG" -n main --query "properties.outputs.participantProjects.value" -o table
```

デプロイ後にプロジェクトの数を増やす場合は、`PARTICIPANT_PROJECT_COUNT` を増やして §5 を再実行します（既存のリソースはそのまま残ります）。数を減らしても、作成済みのプロジェクトは削除されません。ワークショップ当日は、§5 を再実行せずに予備のプロジェクトを使ってください。

デプロイ後、Azure AI Search の層とエージェント検索の課金プランを確認します。`sku` が `basic`、`knowledgeRetrieval` が `standard` であれば問題ありません。

```bash
SEARCH_NAME_OUT="$(az deployment group show -g "$RG" -n main --query properties.outputs.searchName.value -o tsv)"
az resource show -g "$RG" -n "$SEARCH_NAME_OUT" --resource-type Microsoft.Search/searchServices \
  --api-version 2026-03-01-preview \
  --query "{sku:sku.name, semanticSearch:properties.semanticSearch, knowledgeRetrieval:properties.knowledgeRetrieval}" -o json
```

## 6. ナレッジベースを構築する

[setup-knowledge-base.sh](./infra/scripts/setup-knowledge-base.sh) で、架空社内文書のアップロード、Foundry IQ のナレッジソースとナレッジベースの作成、取得テストを行います。§5 で付与されたデータプレーンのロールが反映されるまで数分かかるため、失敗した場合は 1 分おきに最大 5 回再実行します（再実行しても問題ありません）。

```bash
for attempt in 1 2 3 4 5; do
  if "$INFRA_DIR/scripts/setup-knowledge-base.sh" "$RG" main; then
    break
  fi
  echo "Attempt $attempt failed. Waiting 60 seconds for role assignments to propagate..."
  sleep 60
done
```

`OK: <n> reference(s) returned.` が表示されれば完了です。

## 7. 対象リソースの検出と期待値リストの作成

RG 内のリソースを種類ごとに検出し、§2.3 の期待値を `$RBAC_WORKDIR/expected.txt` に出力します。§8〜§10 の前に必ず実行します。

```bash
ROLE_FOUNDRY_OWNER="c883944f-8b7b-4483-af10-35834be79c4a"
ROLE_FOUNDRY_USER="53ca6127-db72-4b80-b1b0-d745d6d5456d"
ROLE_READER="acdd72a7-3385-48ef-bd42-f606fba81ae7"
ROLE_SEARCH_INDEX_DATA_READER="1407120a-92aa-4202-b7e9-c0e197c71c8f"
ROLE_SEARCH_INDEX_DATA_CONTRIBUTOR="8ebe5a00-799e-43f5-93ac-243d3dce84a7"
ROLE_SEARCH_SERVICE_CONTRIBUTOR="7ca78c08-252a-4471-8644-bb5ff32d4ba0"
ROLE_LOG_ANALYTICS_READER="73c42c96-874c-492b-b04d-ab87d138a893"
ROLE_STORAGE_BLOB_DATA_READER="2a2b9908-6ea1-4ae2-8e65-a410df84e7d1"
ROLE_STORAGE_BLOB_DATA_CONTRIBUTOR="ba92f5b4-2d11-453d-a403-e96b0029c9fe"
ROLE_COGNITIVE_SERVICES_USER="a97b65f3-24c7-4388-baec-2e87135dc908"
ROLE_CONTRIBUTOR="b24988ac-6180-42a0-ab88-20f7382dd24c"
ROLE_RBAC_ADMIN="f58310d9-a9f6-439a-9e8d-f62e7b41a168"
ROLE_OWNER="8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
ROLE_FOUNDRY_PROJECT_MANAGER="eadc314b-1a2d-4efa-be10-5d325db5065e"
ROLE_BOT_SERVICE_CONTRIBUTOR="9fc6112f-f48e-4e27-8b09-72a5c94e4ae9"

resolve_resource_id() {
  local type="$1" name="$2" ids count
  if [[ -n "$name" ]]; then
    az resource show -g "$RG" -n "$name" --resource-type "$type" --query id -o tsv
    return
  fi
  ids="$(az resource list -g "$RG" --resource-type "$type" --query "[].id" -o tsv)"
  count="$(printf '%s' "$ids" | grep -c . || true)"
  if [[ "$count" -ne 1 ]]; then
    echo "ERROR: found $count resource(s) of type $type in $RG. Set the name variable explicitly." >&2
    return 1
  fi
  echo "$ids"
}

RG_ID="$(az group show -n "$RG" --query id -o tsv)"
FOUNDRY_ID="$(resolve_resource_id Microsoft.CognitiveServices/accounts "$FOUNDRY_NAME")"
SEARCH_ID="$(resolve_resource_id Microsoft.Search/searchServices "$SEARCH_NAME")"
STORAGE_ID="$(resolve_resource_id Microsoft.Storage/storageAccounts "$STORAGE_NAME")"
LAW_ID="$(resolve_resource_id Microsoft.OperationalInsights/workspaces "$LAW_NAME")"
SEARCH_MI="$(az resource show --ids "$SEARCH_ID" --query identity.principalId -o tsv)"
PROJECTS="$(az rest --method get \
  --url "https://management.azure.com${FOUNDRY_ID}/projects?api-version=2026-03-01" \
  --query "value[].[name, identity.principalId]" -o tsv)"

if [[ "$PARTICIPANT_ACCESS_MODE" == "sharedProject" ]]; then
  PARTICIPANT_FOUNDRY_ROLE="$ROLE_FOUNDRY_USER"
else
  PARTICIPANT_FOUNDRY_ROLE="$ROLE_FOUNDRY_OWNER"
fi

# Format: category|principal label|principal id|principal type|role name|role id|alternative role ids (comma)|scope id
{
  echo "participant|participants group|$PARTICIPANT_GROUP_ID|Group|Foundry participant role|$PARTICIPANT_FOUNDRY_ROLE||$FOUNDRY_ID"
  echo "participant|participants group|$PARTICIPANT_GROUP_ID|Group|Reader|$ROLE_READER||$RG_ID"
  echo "participant|participants group|$PARTICIPANT_GROUP_ID|Group|Search Index Data Reader|$ROLE_SEARCH_INDEX_DATA_READER||$SEARCH_ID"
  echo "participant|participants group|$PARTICIPANT_GROUP_ID|Group|Log Analytics Reader|$ROLE_LOG_ANALYTICS_READER||$LAW_ID"
  while IFS=$'\t' read -r project_name project_mi; do
    [[ -z "$project_name" ]] && continue
    project_name="${project_name##*/}"
    if [[ -z "$project_mi" || "$project_mi" == "None" ]]; then
      echo "WARNING: project $project_name has no system-assigned managed identity; skipped." >&2
      continue
    fi
    echo "identity|project MI: $project_name|$project_mi|ServicePrincipal|Foundry User|$ROLE_FOUNDRY_USER||$FOUNDRY_ID"
    echo "identity|project MI: $project_name|$project_mi|ServicePrincipal|Search Index Data Reader|$ROLE_SEARCH_INDEX_DATA_READER||$SEARCH_ID"
  done <<< "$PROJECTS"
  echo "identity|search MI|$SEARCH_MI|ServicePrincipal|Storage Blob Data Reader|$ROLE_STORAGE_BLOB_DATA_READER||$STORAGE_ID"
  echo "identity|search MI|$SEARCH_MI|ServicePrincipal|Cognitive Services User|$ROLE_COGNITIVE_SERVICES_USER||$FOUNDRY_ID"
  echo "instructor|instructor|$INSTRUCTOR_ID|$INSTRUCTOR_TYPE|Foundry Owner|$ROLE_FOUNDRY_OWNER||$FOUNDRY_ID"
  echo "instructor|instructor|$INSTRUCTOR_ID|$INSTRUCTOR_TYPE|Search Service Contributor|$ROLE_SEARCH_SERVICE_CONTRIBUTOR||$SEARCH_ID"
  echo "instructor|instructor|$INSTRUCTOR_ID|$INSTRUCTOR_TYPE|Search Index Data Contributor|$ROLE_SEARCH_INDEX_DATA_CONTRIBUTOR||$SEARCH_ID"
  echo "instructor|instructor|$INSTRUCTOR_ID|$INSTRUCTOR_TYPE|Storage Blob Data Contributor|$ROLE_STORAGE_BLOB_DATA_CONTRIBUTOR||$STORAGE_ID"
  echo "instructor|instructor|$INSTRUCTOR_ID|$INSTRUCTOR_TYPE|Contributor|$ROLE_CONTRIBUTOR|$ROLE_OWNER|$RG_ID"
  echo "instructor|instructor|$INSTRUCTOR_ID|$INSTRUCTOR_TYPE|Role Based Access Control Administrator|$ROLE_RBAC_ADMIN|$ROLE_OWNER|$RG_ID"
  if [[ "$INCLUDE_TEAMS_PUBLISH" == "true" ]]; then
    echo "teams|participants group|$PARTICIPANT_GROUP_ID|Group|Foundry Project Manager|$ROLE_FOUNDRY_PROJECT_MANAGER|$ROLE_FOUNDRY_OWNER|$FOUNDRY_ID"
    echo "teams|participants group|$PARTICIPANT_GROUP_ID|Group|Azure Bot Service Contributor Role|$ROLE_BOT_SERVICE_CONTRIBUTOR|$ROLE_CONTRIBUTOR,$ROLE_OWNER|$RG_ID"
    echo "teams|instructor|$INSTRUCTOR_ID|$INSTRUCTOR_TYPE|Foundry Project Manager|$ROLE_FOUNDRY_PROJECT_MANAGER|$ROLE_FOUNDRY_OWNER|$FOUNDRY_ID"
    echo "teams|instructor|$INSTRUCTOR_ID|$INSTRUCTOR_TYPE|Azure Bot Service Contributor Role|$ROLE_BOT_SERVICE_CONTRIBUTOR|$ROLE_CONTRIBUTOR,$ROLE_OWNER|$RG_ID"
  fi
} > "$RBAC_WORKDIR/expected.txt"

echo "Resource group : $RG_ID"
echo "Foundry        : ${FOUNDRY_ID##*/}"
echo "Search         : ${SEARCH_ID##*/} (MI: $SEARCH_MI)"
echo "Storage        : ${STORAGE_ID##*/}"
echo "Log Analytics  : ${LAW_ID##*/}"
echo "Projects       :"; printf '%s\n' "$PROJECTS" | sed 's|^[^/]*/|  |'
echo "Expected assignments: $(wc -l < "$RBAC_WORKDIR/expected.txt" | tr -d ' ')"

```

## 8. 現状を全て確認する

### 8.1 各スコープのロール割り当て一覧

対象スコープと親スコープのロール割り当てをすべて表示します。プリンシパル名の解決に Microsoft Graph の読み取り権限を使います。

```bash
for scope in "$RG_ID" "$FOUNDRY_ID" "$SEARCH_ID" "$STORAGE_ID" "$LAW_ID"; do
  echo "=== ${scope##*/} ==="
  az role assignment list --scope "$scope" --include-inherited \
    --query "sort_by([], &roleDefinitionName)[].{principal:principalName, principalType:principalType, role:roleDefinitionName, scope:scope}" \
    -o table
  echo
done

```

Azure CLI の `-o table` は、`id` や `type` という名前の列を表示しない場合があります。表に出す列は `--query` で `subscriptionId` や `principalType` などの別名を指定してください。

### 8.2 期待値との突合

§2.3 の期待値ごとに `OK`／`OK(inherited)`／`OK(alt)`／`MISSING` を表示し、`MISSING` を `$RBAC_WORKDIR/missing.txt` に書き出します。

管理グループのスコープ（`/providers/Microsoft.Management/managementGroups/...`）はサブスクリプションの ARM パスの接頭辞になりません。`--include-inherited` が返す管理グループの割り当ても、継承された親スコープとして判定します。

```bash
# Prints OK, OK(inherited), OK(alt), MISSING, or NO-PRINCIPAL for one expected assignment.
rbac_row_status() {
  local principal="$1" role_id="$2" alt_ids="$3" scope="$4"
  local assignments status="MISSING" accepted a_role a_scope rid scope_lc a_scope_lc
  if [[ -z "$principal" ]]; then
    echo "NO-PRINCIPAL"
    return
  fi
  assignments="$(az role assignment list --scope "$scope" --include-inherited \
    --fill-principal-name false --fill-role-definition-name false \
    --query "[?principalId=='$principal'].[roleDefinitionId, scope]" -o tsv)"
  scope_lc="$(printf '%s' "$scope" | tr '[:upper:]' '[:lower:]')"
  accepted="$role_id ${alt_ids//,/ }"
  while IFS=$'\t' read -r a_role a_scope; do
    [[ -z "$a_role" ]] && continue
    a_scope_lc="$(printf '%s' "$a_scope" | tr '[:upper:]' '[:lower:]')"
    # Only the target scope or its parents grant access. Management group scopes are not path
    # prefixes of subscription scopes, but --include-inherited returns only applicable ones.
    [[ "$scope_lc" == "$a_scope_lc" || "$scope_lc" == "$a_scope_lc"/* || "$a_scope_lc" == "/" \
      || "$a_scope_lc" == /providers/microsoft.management/managementgroups/* ]] || continue
    for rid in $accepted; do
      [[ "${a_role##*/}" == "$rid" ]] || continue
      if [[ "$rid" != "$role_id" ]]; then
        [[ "$status" == "MISSING" ]] && status="OK(alt)"
      elif [[ "$scope_lc" == "$a_scope_lc" ]]; then
        status="OK"
      elif [[ "$status" != "OK" ]]; then
        status="OK(inherited)"
      fi
    done
  done <<< "$assignments"
  echo "$status"
}

check_rbac() {
  : > "$RBAC_WORKDIR/missing.txt"
  local category label principal ptype role_name role_id alt_ids scope status ok=0 ng=0
  printf '%-14s %-11s %-38s %-40s %s\n' STATUS CATEGORY PRINCIPAL ROLE SCOPE
  while IFS='|' read -r category label principal ptype role_name role_id alt_ids scope; do
    status="$(rbac_row_status "$principal" "$role_id" "$alt_ids" "$scope")"
    printf '%-14s %-11s %-38s %-40s %s\n' "$status" "$category" "$label" "$role_name" "${scope##*/}"
    if [[ "$status" == OK* ]]; then
      ok=$((ok + 1))
    else
      ng=$((ng + 1))
      echo "$category|$label|$principal|$ptype|$role_name|$role_id|$alt_ids|$scope" >> "$RBAC_WORKDIR/missing.txt"
    fi
  done < "$RBAC_WORKDIR/expected.txt"
  echo
  echo "Summary: OK=$ok, MISSING=$ng"
  [[ "$ng" -eq 0 ]]
}

check_rbac

```

### 8.3 Teams Publish 用のリソースプロバイダー（`INCLUDE_TEAMS_PUBLISH=true` の場合）

```bash
if [[ "$INCLUDE_TEAMS_PUBLISH" == "true" ]]; then
  echo "Microsoft.BotService: $(az provider show --namespace Microsoft.BotService --query registrationState -o tsv)"
fi

```

`Registered` 以外の場合は §9 で登録します。

## 9. 不足しているロールを付与する

§8.2 で `MISSING` になったロールだけを作成します。既存の割り当ては変更しないため、再実行しても安全です。作成した割り当て ID は `$RBAC_WORKDIR/created.txt` に記録します。

前提:

- 実行者に対象 RG での `Role Based Access Control Administrator`、`User Access Administrator`、`Owner` のいずれかが必要です。講師自身の `Contributor`／`Role Based Access Control Administrator` が未付与の場合は、サブスクリプション管理者が実行します。
- `Role Based Access Control Administrator` は条件なしで付与します。付与できるロールを制限する場合は、Azure ポータルで条件を追加してください。
- `Microsoft.BotService` の登録には、サブスクリプションでの `Microsoft.BotService/register/action`（`Contributor` 以上）が必要です。

```bash
grant_missing_rbac() {
  local category label principal ptype role_name role_id alt_ids scope id
  check_rbac > /dev/null || true
  if [[ ! -s "$RBAC_WORKDIR/missing.txt" ]]; then
    echo "Nothing to grant."
    return 0
  fi
  while IFS='|' read -r category label principal ptype role_name role_id alt_ids scope; do
    if [[ -z "$principal" ]]; then
      echo "SKIPPED  $label / $role_name: principal id is empty"
      continue
    fi
    # An alternative role (for example Foundry Owner) may have been granted earlier in this loop.
    if [[ -n "$alt_ids" && "$(rbac_row_status "$principal" "$role_id" "$alt_ids" "$scope")" == OK* ]]; then
      echo "SKIPPED  $label / $role_name: already satisfied by an alternative role"
      continue
    fi
    if id="$(az role assignment create \
      --assignee-object-id "$principal" \
      --assignee-principal-type "$ptype" \
      --role "$role_id" \
      --scope "$scope" \
      --query id -o tsv)"; then
      echo "$id" >> "$RBAC_WORKDIR/created.txt"
      echo "CREATED  $label / $role_name on ${scope##*/}"
    else
      echo "FAILED   $label / $role_name on ${scope##*/}" >&2
    fi
  done < "$RBAC_WORKDIR/missing.txt"
}

grant_missing_rbac
check_rbac

if [[ "$INCLUDE_TEAMS_PUBLISH" == "true" \
  && "$(az provider show --namespace Microsoft.BotService --query registrationState -o tsv)" != "Registered" ]]; then
  az provider register --namespace Microsoft.BotService --wait
  echo "Microsoft.BotService: $(az provider show --namespace Microsoft.BotService --query registrationState -o tsv)"
fi

```

割り当ては作成直後から一覧に表示されますが、データプレーン（Search、Storage、Foundry のエージェント実行など）への反映には数分かかる場合があります。

## 10. プロジェクトを追加した場合: 追加したプロジェクトの MI にロールを付与する

§5 で作成した参加者用プロジェクトの MI には、デプロイ時にロールを割り当て済みです。この章は、予備のプロジェクトが足りずに当日ポータルや CLI でプロジェクトを追加した場合や、参加者が誤って新しいプロジェクトを作成した場合だけ実行します。

[grant-project-access.sh](./infra/scripts/grant-project-access.sh) は、Foundry リソース配下の全プロジェクトの MI に `Foundry User` と `Search Index Data Reader` を付与します。付与済みのプロジェクトに再実行しても問題ありません。

```bash
"$INFRA_DIR/scripts/grant-project-access.sh" "$RG" main
```

続けて §7 のコードブロックと `check_rbac` を再実行し、`project MI: <プロジェクト名>` の行がすべて `OK` になることを確認します。ロールの反映には数分かかる場合があります。

ナレッジベースへの接続（Azure AI Search 接続と RemoteTool 接続）は、参加者が Lab 2 の **Connect to Foundry IQ** で操作したときにポータルが作成します。接続名は Foundry リソース内で一意である必要があるため、事前には作成しません。

## 11. 後片付け（ワークショップ後）

リソースグループを削除すると、ロール割り当てと Azure Bot Service も一緒に削除されます。Foundry リソースは削除後も一定期間「削除済み」として残り、同じ名前で再作成できないため消去（purge）します。消去にはサブスクリプションスコープの `Contributor` 以上が必要です。参加者グループ（Entra ID）は削除しません。

```bash
FOUNDRY_NAME_OUT="$(az deployment group show -g "$RG" -n main --query properties.outputs.foundryName.value -o tsv)"
az group delete -n "$RG" --yes
az cognitiveservices account purge -l "$LOCATION" -g "$RG" -n "$FOUNDRY_NAME_OUT"
az cognitiveservices account list-deleted --query "[?name=='$FOUNDRY_NAME_OUT'].name" -o tsv
```

最後のコマンドで何も表示されなければ、消去は完了しています。
