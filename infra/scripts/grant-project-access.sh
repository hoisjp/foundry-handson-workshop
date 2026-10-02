#!/usr/bin/env bash
# Grant every project under the workshop Foundry resource access to the shared knowledge base.
# main.bicep already grants these roles to the shared and participant projects it creates.
# Run this only for projects added after deployment (for example, on the day of the workshop). Safe to re-run.
# For each project managed identity:
#   - Foundry User on the Foundry resource
#   - Search Index Data Reader on the search service
# Project connections are not created here. When a participant selects "Connect to Foundry IQ" in the
# portal, Foundry creates the Azure AI Search connection and a uniquely named RemoteTool connection.
# Connection names must be unique within the Foundry resource, so a fixed name can't be reused per project.
#
# Usage: ./grant-project-access.sh <resource-group> [deployment-name]
# Requires: Azure CLI, and permission to create role assignments on the resource group
#           (Owner, User Access Administrator, or Role Based Access Control Administrator).
set -euo pipefail

RG="${1:?resource group is required}"
DEPLOYMENT="${2:-main}"

ACCOUNT_API="2026-03-01"

FOUNDRY_ROLE_USER="53ca6127-db72-4b80-b1b0-d745d6d5456d"
SEARCH_INDEX_DATA_READER="1407120a-92aa-4202-b7e9-c0e197c71c8f"

out() {
  az deployment group show -g "$RG" -n "$DEPLOYMENT" --query "properties.outputs.$1.value" -o tsv
}

FOUNDRY_NAME="$(out foundryName)"
SEARCH_NAME="$(out searchName)"
FOUNDRY_ID="$(az resource show -g "$RG" -n "$FOUNDRY_NAME" --resource-type Microsoft.CognitiveServices/accounts --query id -o tsv)"
SEARCH_ID="$(az resource show -g "$RG" -n "$SEARCH_NAME" --resource-type Microsoft.Search/searchServices --query id -o tsv)"

echo "Foundry: $FOUNDRY_NAME"
echo "Search:  $SEARCH_NAME"

projects="$(az rest --method get \
  --url "https://management.azure.com$FOUNDRY_ID/projects?api-version=$ACCOUNT_API" \
  --query "value[].[name, identity.principalId]" -o tsv)"

if [[ -z "$projects" ]]; then
  echo "No projects found." >&2
  exit 1
fi

assign() {
  local principal="$1" role="$2" scope="$3"
  az role assignment create \
    --assignee-object-id "$principal" \
    --assignee-principal-type ServicePrincipal \
    --role "$role" \
    --scope "$scope" \
    --output none || echo "    WARNING: failed to assign role $role on $scope" >&2
}

count=0
while IFS=$'\t' read -r project_name principal_id; do
  echo "==> $project_name"
  if [[ -z "$principal_id" || "$principal_id" == "None" ]]; then
    echo "    skipped: project has no system-assigned managed identity"
    continue
  fi
  assign "$principal_id" "$FOUNDRY_ROLE_USER" "$FOUNDRY_ID"
  assign "$principal_id" "$SEARCH_INDEX_DATA_READER" "$SEARCH_ID"
  echo "    roles assigned"
  count=$((count + 1))
done <<< "$projects"

echo "Done: $count project(s) processed. Role assignments can take a few minutes to propagate."
