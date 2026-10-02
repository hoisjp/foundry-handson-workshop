# Microsoft Foundry 入門ハンズオン 参加者用手順書（2026-09-25）

この手順書に沿って、架空の会社「コントソ株式会社」の社内規程に答える **社内ヘルプデスクエージェント** を作ります。

> **お願い**
> - この環境は参加者全員で共有しています。**モデルのデプロイやリソースの設定は変更しないでください。**
> - ポータルの画面は更新されることがあります。手順書と表示が違うときは、講師に声をかけてください。
> - ナレッジベースの文書はすべて架空のものです。

## 0. 事前に講師から受け取る情報

| 項目 | 値（当日記入） |
|---|---|
| Foundry ポータル | https://ai.azure.com |
| Foundry リソース名 | `____________________` |
| 自分のプロジェクト名 | 講師から割り当てられた番号のプロジェクト（例: `proj-07`） |
| ナレッジベース名 | `contoso-policies-kb` |

> **権限について:** このワークショップに必要な Azure の権限（追加演習の Teams 公開用を含む）は、講師が事前に設定します。詳細は [setup-guide.md §2](./setup-guide.md#2-必要な権限) を参照してください。

## 1. Lab 0: 自分のプロジェクトを開く（5 分）

**プロジェクト** は、エージェント・ファイル・評価などをまとめる自分専用の作業場所です。講師が用意した Foundry リソースの中に、参加者ごとのプロジェクト（`proj-01`、`proj-02`、…）を作成してあります。

1. ブラウザーで https://ai.azure.com を開き、会社のアカウントでサインインします。
2. 画面上部の **New Foundry** の切り替えがオンになっていることを確認します。
3. 左上のプロジェクト名を選び、プロジェクトの一覧を表示します。
4. 講師から割り当てられたプロジェクト（例: `proj-07`）を選びます。
5. 左上のプロジェクト名が自分のプロジェクトに切り替わったことを確認します。

> **注意:**
> - 一覧には、ほかの参加者のプロジェクトも表示されます。**割り当てられたプロジェクト以外は開かないでください。**
> - 新しいプロジェクトやリソースは作らないでください。
> - 自分のプロジェクトが一覧にない場合は、講師に声をかけてください。

- [ ] 自分のプロジェクトを開けた（完了したら講師に知らせてください）

## 2. Lab 1: モデルをプレイグラウンドで試す（15 分）

### 2.1 モデルカタログを見る

1. 上部メニューの **Discover** を開き、**Models** を選びます。
2. Microsoft、OpenAI、Meta、Mistral などのモデルが並んでいることを確認します。モデルを 1 つ選び、説明・対応機能・ベンチマークを見てみます。

> Foundry では、カタログのモデルを **デプロイ** すると使えるようになります。今回は講師が事前にデプロイ済みです。

### 2.2 プレイグラウンドで質問する

1. 上部メニューの **Build** を開き、**Models** を選びます。デプロイ済みのモデルが一覧表示されます。
2. `gpt-5.4-mini` を選び、プレイグラウンドを開きます。
3. 次の質問をしてみます。

   ```text
   コントソ株式会社のテレワーク手当はいくらですか？
   ```

4. 回答を確認します。モデルはこの会社の規程を知らないため、推測で答えるか、わからないと答えるはずです。

   > **ポイント:** モデルは学習データにない社内情報を知りません。Lab 2 では、社内文書を検索させて正しく答えさせます。

### 2.3 システムプロンプトを変えてみる

1. **Instructions**（システムメッセージ）に次を入力します。

   ```text
   あなたは新入社員向けの研修講師です。専門用語を使わず、3 行以内で答えてください。
   ```

2. 次の質問をして、回答のスタイルが変わることを確認します。

   ```text
   生成 AI とは何ですか？
   ```

### 2.4 モデルを比較する

1. 使用するモデル（デプロイ）を `gpt-4.1-mini` に切り替え、同じ質問をします。
2. 回答の内容・長さ・速さを比べます。`gpt-5.4-mini` は内部で推論（reasoning）してから答えるモデルです。

### 2.5 コードを確認する

1. プレイグラウンドの **View code**（コードの表示）を開き、今の操作を API で呼び出すコードが表示されることを確認します（Lab 3 で使います）。

- [ ] モデルが社内情報を知らないことを確認した
- [ ] システムプロンプトとモデルの違いで回答が変わることを確認した

## 3. Lab 2: 社内文書を検索するエージェントを作る（25 分）

**エージェント** は、モデル・指示（Instructions）・ツールを組み合わせたものです。今回は、講師が用意した **Foundry IQ のナレッジベース**（社内規程と FAQ を Azure AI Search で検索できるようにしたもの）をツールとして接続します。

### 3.1 エージェントを作る

1. 上部メニューの **Build** を開き、**Agents** を選びます。
2. **New agent** > **Build an agent** を選び、**Agent name** を `policy-agent` にして **Create agent and open playground** を選びます（**Interaction mode** は **Text** のまま）。
3. **Model** で `gpt-5.4-mini` を選びます（既定では別のモデルが選ばれてる可能性があります）。
4. **Instructions** に次を貼り付けます。

   ```text
   あなたはコントソ株式会社の社内ヘルプデスクです。
   - 社内規程・休暇・経費・テレワーク・IT に関する質問には、必ずナレッジベースを検索してから答えてください。
   - 回答は日本語で、結論を先に、根拠となる規程名と条番号を添えてください。
   - ナレッジベースに情報がない場合は、推測せず「社内文書に記載がないため回答できません。担当部署に確認してください。」と答えてください。
   ```

5. 右上の **Save** で保存します。

> **Tools** には既定で **Web search** が追加されています。このまま進めて構いません（Instructions により、社内規程の質問はナレッジベースを優先します）。

### 3.2 ナレッジベースを接続する

1. エージェントの設定画面の **Knowledge** で **Add** > **Connect to Foundry IQ** を選びます。
2. **Connection** が「No connections available」の場合は、**Connect to an AI Search resource** を選びます。保存の確認が表示されたら **Save** を選びます。
   1. **Knowledge (Foundry IQ)** 画面で、**Foundry IQ resource** に講師が用意した Azure AI Search（名前に `search` を含むもの）を選びます。
   2. **Auth Type** を **Project Managed Identity** に変更し、**Connect** を選びます。
   3. ナレッジベースの一覧に `contoso-policies-kb` が表示されたら、**Build** > **Agents** から `policy-agent` を開き直し、手順 1 に戻ります。
3. **Connection** に AI Search が選ばれていることを確認し、**Knowledge base** で `contoso-policies-kb` を選んで **Connect** を選びます。
4. **Knowledge** に `contoso-policies-kb` が表示されたら、**Save** で保存します。

> 一覧に `contoso-policies-kb` が表示されない場合は、講師に声をかけてください（アクセス権の反映に数分かかることがあります）。

### 3.3 テストする

エージェントのプレイグラウンドで、次の質問を **順番に、自分のペースで** 試します。回答と **引用（出典）** を確認してください。

| # | 質問 | 確認するポイント |
|---|---|---|
| 1 | テレワーク手当はいくらもらえますか？ | Lab 1 と回答がどう変わったか |
| 2 | 大阪に 1 泊で出張します。宿泊費の上限と日当は？ | 表の中の数値を正しく読めているか |
| 3 | 勤続 3 年の有給休暇は何日付与されますか？ | 条件に合う行を選べているか |
| 4 | ホテルで VPN がエラー E-809 になります | FAQ から対処法を答えられるか |
| 5 | 在宅勤務の自宅のネット代を経費精算できますか？ | 複数の文書を組み合わせて答えられるか |
| 6 | 社員食堂の今日のメニューは？ | 推測せずに「回答できない」と答えるか |

### 3.4 指示を変えて比べる（時間があれば）

1. Instructions から「推測せず…」の行を削除し、質問 6 をもう一度試します。
2. 回答がどう変わるかを確認したら、元に戻して保存します。

- [ ] 社内文書に基づく回答と引用を確認した
- [ ] 範囲外の質問に「回答できない」と答えることを確認した

## 4. Lab 3: Python から自分のエージェントを呼び出す（15 分）

ポータルで作ったエージェントを、そのまま API から使えることを確認します。

### 4.1 Cloud Shell を開く

1. 別のタブで https://portal.azure.com を開き、上部の **Cloud Shell** アイコン（`>_`）を選びます。
2. **Bash** を選びます。ストレージの設定を聞かれたら **No storage account required**（ストレージアカウントは不要）を選び、サブスクリプションを選んで適用します。
3. Python のバージョンを確認します（3.10 以上であること）。

   ```bash
   python3 --version
   ```

### 4.2 準備する

1. SDK をインストールします。

   ```bash
   mkdir -p ~/foundry-lab && cd ~/foundry-lab
   pip install --user "azure-ai-projects>=2.3.0" azure-identity
   ```

2. Foundry ポータルで自分のプロジェクトのトップ（**Home** または **Overview**）を開き、**Project endpoint** をコピーします。形式は `https://<リソース名>.services.ai.azure.com/api/projects/<プロジェクト名>` です。
3. Cloud Shell で環境変数を設定します。

   ```bash
   export FOUNDRY_PROJECT_ENDPOINT="<コピーしたプロジェクトエンドポイント>"
   export AGENT_NAME="policy-agent"
   ```

### 4.3 モデルを呼び出す

1. スクリプトを作ります。

   ```bash
   cat > call_model.py <<'EOF'
   import os

   from azure.ai.projects import AIProjectClient
   from azure.identity import DefaultAzureCredential

   PROJECT_ENDPOINT = os.environ["FOUNDRY_PROJECT_ENDPOINT"]
   MODEL_DEPLOYMENT = os.environ.get("MODEL_DEPLOYMENT", "gpt-5.4-mini")

   project = AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=DefaultAzureCredential())
   openai = project.get_openai_client()

   response = openai.responses.create(
       model=MODEL_DEPLOYMENT,
       input="Explain Microsoft Foundry in two sentences for a first-time user. Answer in Japanese.",
   )
   print(response.output_text)
   EOF
   ```

2. 実行します。

   ```bash
   python3 call_model.py
   ```

### 4.4 エージェントと会話する

1. スクリプトを作ります。

   ```bash
   cat > chat_with_agent.py <<'EOF'
   import os

   from azure.ai.projects import AIProjectClient
   from azure.identity import DefaultAzureCredential

   PROJECT_ENDPOINT = os.environ["FOUNDRY_PROJECT_ENDPOINT"]
   AGENT_NAME = os.environ["AGENT_NAME"]

   project = AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=DefaultAzureCredential())
   openai = project.get_openai_client()

   # A conversation keeps the chat history on the service side.
   conversation = openai.conversations.create()
   print(f"Connected to agent '{AGENT_NAME}'. Type 'exit' to quit.")

   while True:
       question = input("\nYou> ").strip()
       if not question:
           continue
       if question.lower() in {"exit", "quit"}:
           break

       response = openai.responses.create(
           conversation=conversation.id,
           input=question,
           extra_body={"agent_reference": {"name": AGENT_NAME, "type": "agent_reference"}},
       )
       print(f"\nAgent> {response.output_text}")
   EOF
   ```

2. 実行して、Lab 2 の質問をしてみます。続けて「では、2 泊ならいくらまで？」のように前の質問を受けた質問をすると、会話の履歴が引き継がれていることを確認できます。

   ```bash
   python3 chat_with_agent.py
   ```

- [ ] Python からエージェントの回答を得られた
- [ ] 会話の履歴が引き継がれることを確認した

## 5. Lab 4: トレースで中身を見る（10 分）

### 5.1 トレースを有効にする

1. Foundry ポータルの **Build** > **Agents** で `policy-agent` を開き、**Traces** タブを選びます。
2. **Connect** を選びます。**Monitor settings** で **Application insights resource name** に講師が用意した Application Insights（名前に `appi` を含むもの）を選び、**Auth Type** は既定の **API Key** のまま **Connect** を選びます。
3. プレイグラウンドで Lab 2 の質問を 1〜2 回もう一度実行します。

### 5.2 トレースを確認する

1. **Traces** タブに実行記録が表示されます（数分かかることがあります）。
2. 1 件を開き、次を確認します。
   - ナレッジベースの呼び出し（`knowledge_base_retrieve`）が行われたか
   - モデル呼び出しの回数、入出力のトークン数
   - 全体の処理時間と、どこに時間がかかっているか

### 5.3 講師のデモを見る

- **評価（Evaluation）:** テスト質問の一覧を使い、回答の品質（意図の理解、指示の順守など）を自動で採点する方法
- **ガードレール（Guardrails）:** 有害なコンテンツやプロンプトインジェクションを検知・ブロックする設定

- [ ] トレースでツール呼び出しとトークン数を確認した

## 6. まとめと後片付け（5 分）

1. 今日使ったもの・作ったもの: 講師が用意した自分のプロジェクト、ナレッジベースを接続したエージェント、エージェントを呼び出す Python スクリプト
2. 後片付け（任意）: **Build** > **Agents** で `policy-agent` を削除します。プロジェクトとリソースは講師がまとめて削除します。第 7 章で Teams に公開した場合、Publish で作成された Azure Bot Service も講師が削除します。
3. 自習用リンク:
   - [What is Microsoft Foundry?](https://learn.microsoft.com/azure/foundry/what-is-foundry)
   - [Quickstart: Get started with Microsoft Foundry SDK](https://learn.microsoft.com/azure/foundry/quickstarts/get-started-code)
   - [What is Foundry IQ?](https://learn.microsoft.com/azure/foundry/agents/concepts/what-is-foundry-iq)

## 7. 追加演習: エージェントを Teams に公開する（任意、10 分）

Lab 2 で作った `policy-agent` を、公開範囲 **Just you**（自分だけ）で Microsoft Teams／Microsoft 365 Copilot に公開し、Teams から質問できることを確認します。**Just you** は Microsoft 365 管理者の承認が不要です。

> **事前準備（講師）**
> - [setup-guide.md §2.2](./setup-guide.md#22-foundry-agent-を-microsoft-teams-に-publish-するための権限) の Azure 側の権限を付与しておく。[setup-guide.md](./setup-guide.md) を `INCLUDE_TEAMS_PUBLISH=true` で実行すると、参加者グループへの `Azure Bot Service Contributor Role` の付与と `Microsoft.BotService` の登録まで確認できる。
> - 参加者が Teams と Microsoft 365 Copilot Chat を使えることを確認しておく。Microsoft 365 Copilot の有償ライセンスは不要だが、Copilot Chat を利用できる Microsoft 365 ライセンス（Microsoft Learn では Business Basic／Standard／Premium、E3／E5 などが対象）と、Teams を利用できることが必要。Copilot Chat を使えないユーザーは、公開はできても Teams 側でエージェントを確認できない。

### 7.1 公開する

1. Foundry ポータルの **Build** > **Agents** で `policy-agent` を開き、プレイグラウンドで Lab 2 の質問 1 を試して正しく回答することを確認します。
2. 右上の **Publish** を選びます。**Active version** が `Latest` になっていることを確認し、**Teams & Microsoft 365 Copilot** を選びます。
3. **Publish to Teams and Microsoft 365** ダイアログで、次を入力します。**Azure bot services** は自動で作成・入力されるため変更できません。

   | 項目 | 入力する値 |
   |---|---|
   | **Agent name** | `contoso-helpdesk-<氏名のローマ字>`（Teams に表示される名前） |
   | **Publish version** | `1.0.0`（先頭を `0` にはできない） |
   | **Short description** | `コントソ社内規程に答えるヘルプデスク` |
   | **Description** | `社内規程・休暇・経費・テレワーク・IT の質問に、社内文書を根拠に回答します。` |
   | **Developer** | 自分の氏名（32 文字以内） |

   **More** の **Developer website**、**Terms of use**、**Privacy statement** は既定値（`https://example.com`）のままで構いません。入力欄は利用者に表示されるため、秘密情報を入力しないでください。

4. **Next: Publish options** を選びます。
5. **Direct publish** タブの **Choose who can use this agent** で **Just you** が選ばれていることを確認します。**People in your organization** は選ばないでください（管理者の承認が必要になります）。
6. **Publish** を選び、**Publish successful** が表示されることを確認します。ダイアログには、エージェントを使える場所（Microsoft 365 Copilot の **All agents** > **Your agents**、Teams の **Apps** > **Manage your apps**）が表示されます。**Done** で閉じます。

### 7.2 Teams で確認する

1. Microsoft Teams（デスクトップアプリ、または https://teams.microsoft.com ）を開き、左側の **Copilot** を選びます。
2. **All agents** を選んでエージェントストアを開き、**Your agents** に `contoso-helpdesk-<氏名のローマ字>` が表示されることを確認します。
   - Teams の **Apps** > **Manage your apps** にも表示されます。
   - Microsoft 365 Copilot アプリ（ https://m365.cloud.microsoft/chat ）の **Agents** > **All agents** からも同じエージェントストアを開けます。
3. エージェントを開き、Lab 2 の質問 1（テレワーク手当）を送信して、Foundry のプレイグラウンドと同じ内容の回答が返ることを確認します。

| 症状 | 対処 |
|---|---|
| **Your agents** に表示されない | エージェントストアのキャッシュは約 1 時間ごとに更新される。サインアウトして再度サインインするか、しばらく待ってから開き直す |
| Teams に **Copilot** や **All agents** が表示されない | Copilot Chat を利用できるライセンスが割り当てられていない可能性がある。講師に確認する |
| ダイアログを開いたときに `AuthorizationFailed`（`Microsoft.BotService/botServices/write`）になる | `Azure Bot Service Contributor Role` がない、またはまだ反映されていない。講師に確認し、数分待ってからダイアログを開き直す |
| エージェントを開けるが、質問すると権限エラーになる | **Just you** の公開では、利用者に Azure の権限（プロジェクトまたはエージェントの `Foundry Agent Consumer` 以上）が必要。講師に確認する |
| プレイグラウンドでは回答できるが、Teams ではナレッジベースの検索に失敗する | エージェントが使う Azure リソースへの権限が不足している。講師に連絡する |

> **補足:** **Publish** ダイアログを開いた時点で、ワークショップのリソースグループに Azure Bot Service（Teams チャネル設定済み）が作成され、エージェントに Teams 用の通信設定が追加されます。最後の **Publish** を押さずにダイアログを閉じても、これらは残ります。

- [ ] `policy-agent` を **Just you** で公開できた
- [ ] Teams の **Your agents** にエージェントが表示され、質問に回答した

参照: [Publish agents to Microsoft Copilot and Microsoft Teams](https://learn.microsoft.com/azure/foundry/agents/how-to/publish-copilot)、[Troubleshoot publishing agents to Microsoft Copilot and Microsoft Teams](https://learn.microsoft.com/azure/foundry/agents/how-to/troubleshoot-publish-copilot)、[Microsoft 365 Copilot Chat の要件](https://learn.microsoft.com/microsoft-365/copilot/microsoft-365-copilot-chat-requirements)
