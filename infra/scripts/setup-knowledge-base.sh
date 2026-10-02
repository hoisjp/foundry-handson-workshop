#!/usr/bin/env bash
# Build the shared Foundry IQ knowledge base used in Lab 2.
# 1) Upload the fictional policy documents to Blob Storage.
# 2) Create a blob knowledge source and a knowledge base on Azure AI Search.
# 3) Run a smoke-test retrieve until the documents are indexed.
#
# Usage: ./setup-knowledge-base.sh <resource-group> [deployment-name]
# Requires: Azure CLI (logged in as the instructor principal used in main.bicep).
set -euo pipefail

RG="${1:?resource group is required}"
DEPLOYMENT="${2:-main}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCS_DIR="${DOCS_DIR:-$SCRIPT_DIR/../../sample-docs}"

SEARCH_API="2026-08-01-preview"
KS_NAME="${KS_NAME:-contoso-policies-ks}"
KB_NAME="${KB_NAME:-contoso-policies-kb}"
EMBEDDING_DEPLOYMENT="${EMBEDDING_DEPLOYMENT:-text-embedding-3-large}"
PLANNER_DEPLOYMENT="${PLANNER_DEPLOYMENT:-gpt-5-mini}"

out() {
  az deployment group show -g "$RG" -n "$DEPLOYMENT" --query "properties.outputs.$1.value" -o tsv
}

SEARCH_ENDPOINT="$(out searchEndpoint)"
OPENAI_ENDPOINT="$(out openAiEndpoint)"
STORAGE_NAME="$(out storageName)"
STORAGE_ID="$(out storageResourceId)"
CONTAINER="$(out docsContainerName)"

echo "Search:  $SEARCH_ENDPOINT"
echo "OpenAI:  $OPENAI_ENDPOINT"
echo "Storage: $STORAGE_NAME/$CONTAINER"

echo "==> Uploading documents from $DOCS_DIR"
az storage blob upload-batch \
  --auth-mode login \
  --account-name "$STORAGE_NAME" \
  --destination "$CONTAINER" \
  --source "$DOCS_DIR" \
  --pattern "*.md" \
  --overwrite \
  --output none

search_put() {
  az rest --method put \
    --resource "https://search.azure.com" \
    --url "$SEARCH_ENDPOINT/$1?api-version=$SEARCH_API" \
    --headers "Content-Type=application/json" \
    --body "$2" \
    --output none
}

echo "==> Creating knowledge source: $KS_NAME"
search_put "knowledgesources/$KS_NAME" "$(cat <<EOF
{
  "name": "$KS_NAME",
  "kind": "azureBlob",
  "description": "Contoso internal policies and IT helpdesk FAQ (fictional, for workshop use).",
  "azureBlobParameters": {
    "connectionString": "ResourceId=$STORAGE_ID;",
    "containerName": "$CONTAINER",
    "isADLSGen2": false,
    "ingestionParameters": {
      "networkAccessMode": "public",
      "contentExtractionMode": "minimal",
      "embeddingModel": {
        "kind": "azureOpenAI",
        "azureOpenAIParameters": {
          "resourceUri": "$OPENAI_ENDPOINT",
          "deploymentId": "$EMBEDDING_DEPLOYMENT",
          "modelName": "$EMBEDDING_DEPLOYMENT"
        }
      },
      "ingestionSchedule": null
    }
  }
}
EOF
)"

echo "==> Creating knowledge base: $KB_NAME"
search_put "knowledgebases/$KB_NAME" "$(cat <<EOF
{
  "name": "$KB_NAME",
  "description": "Answers questions about Contoso telework, expense, leave policies and IT helpdesk FAQ.",
  "retrievalInstructions": "Use this knowledge base for any question about Contoso internal rules, allowances, leave, expenses, telework, or IT support.",
  "outputMode": "extractiveData",
  "knowledgeSources": [ { "name": "$KS_NAME" } ],
  "models": [
    {
      "kind": "azureOpenAI",
      "azureOpenAIParameters": {
        "resourceUri": "$OPENAI_ENDPOINT",
        "deploymentId": "$PLANNER_DEPLOYMENT",
        "modelName": "$PLANNER_DEPLOYMENT"
      }
    }
  ],
  "retrievalReasoningEffort": { "kind": "low" }
}
EOF
)"

echo "==> Smoke test (waits for indexing, up to ~10 minutes)"
for i in $(seq 1 20); do
  refs="$(az rest --method post \
    --resource "https://search.azure.com" \
    --url "$SEARCH_ENDPOINT/knowledgebases/$KB_NAME/retrieve?api-version=$SEARCH_API" \
    --headers "Content-Type=application/json" \
    --body '{"intents":[{"type":"semantic","search":"telework allowance amount"}]}' \
    --query "length(references)" -o tsv 2>/dev/null || echo 0)"
  if [[ "${refs:-0}" =~ ^[0-9]+$ ]] && (( refs > 0 )); then
    echo "OK: $refs reference(s) returned."
    echo "MCP endpoint: $SEARCH_ENDPOINT/knowledgebases/$KB_NAME/mcp?api-version=$SEARCH_API"
    exit 0
  fi
  echo "  not ready yet (attempt $i/20), retrying in 30s..."
  sleep 30
done

echo "ERROR: knowledge base returned no references. Check the indexer status in the Azure portal." >&2
exit 1
