// Shared environment for the Microsoft Foundry beginner hands-on workshop.
// Deploys: Foundry resource (+ shared project, participant projects, model deployments),
// Azure AI Search (Basic), Storage (knowledge source documents), Log Analytics + Application Insights, and RBAC.
targetScope = 'resourceGroup'

@description('Prefix for resource names (lowercase letters and digits, 3-12 chars).')
@minLength(3)
@maxLength(12)
param prefix string

@description('Region for the Foundry resource, models, storage, and monitoring.')
param location string = 'eastus2'

@description('Region for Azure AI Search. East US 2 does not accept new search services (high demand).')
param searchLocation string = 'centralus'

@description('Object ID of the Entra ID security group that contains all participants.')
param participantsGroupObjectId string

@description('Object ID of the instructor (user) who builds the knowledge base and runs setup scripts.')
param instructorPrincipalId string

@description('Principal type of the instructor principal.')
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param instructorPrincipalType string = 'User'

@description('ownProject: participants get Foundry Owner on the Foundry resource and each works in their own project from participantProjectNames. sharedProject: participants get Foundry User and work in the shared project.')
@allowed([
  'ownProject'
  'sharedProject'
])
param participantAccessMode string = 'ownProject'

@description('Deploy participant, instructor, and managed-identity role assignments.')
param deployWorkshopRbac bool = true

@description('Name of the shared (default) project. Used by the instructor and as the fallback workspace.')
param sharedProjectName string = 'workshop-shared'

@description('Names of the participant projects to pre-create (one per participant plus spares), for example proj-01 to proj-32. Each project managed identity gets Foundry User and Search Index Data Reader. Use an empty array for sharedProject mode.')
param participantProjectNames array = []

@description('Model deployments. capacity is in units of 1,000 TPM (GlobalStandard).')
param modelDeployments array = [
  {
    name: 'gpt-5.4-mini'
    model: 'gpt-5.4-mini'
    version: '2026-03-17'
    capacity: 300
  }
  {
    name: 'gpt-4.1-mini'
    model: 'gpt-4.1-mini'
    version: '2025-04-14'
    capacity: 100
  }
  {
    name: 'gpt-5-mini'
    model: 'gpt-5-mini'
    version: '2025-08-07'
    capacity: 100
  }
  {
    name: 'text-embedding-3-large'
    model: 'text-embedding-3-large'
    version: '1'
    capacity: 100
  }
]

@description('Blob container name for the fictional policy documents.')
param docsContainerName string = 'contoso-policies'

param tags object = {
  workload: 'foundry-handson-workshop'
}

var suffix = substring(uniqueString(resourceGroup().id), 0, 6)
var foundryName = '${prefix}-foundry-${suffix}'
var searchName = '${prefix}-search-${suffix}'
var storageName = take('${prefix}st${suffix}', 24)
var logName = '${prefix}-log-${suffix}'
var appInsightsName = '${prefix}-appi-${suffix}'

// Built-in role definition IDs (IDs are unchanged by the Foundry role rename).
var roleIds = {
  foundryUser: '53ca6127-db72-4b80-b1b0-d745d6d5456d'
  foundryOwner: 'c883944f-8b7b-4483-af10-35834be79c4a'
  cognitiveServicesUser: 'a97b65f3-24c7-4388-baec-2e87135dc908'
  searchIndexDataReader: '1407120a-92aa-4202-b7e9-c0e197c71c8f'
  searchIndexDataContributor: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  searchServiceContributor: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
  storageBlobDataReader: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  storageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  logAnalyticsReader: '73c42c96-874c-492b-b04d-ab87d138a893'
}

var participantFoundryRole = participantAccessMode == 'ownProject' ? roleIds.foundryOwner : roleIds.foundryUser

// ---------- Foundry ----------

resource foundry 'Microsoft.CognitiveServices/accounts@2026-03-01' = {
  name: foundryName
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: foundryName
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

resource sharedProject 'Microsoft.CognitiveServices/accounts/projects@2026-03-01' = {
  parent: foundry
  name: sharedProjectName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: sharedProjectName
    description: 'Shared project for the instructor and fallback workspace for participants.'
  }
}

// Deploy models one at a time to avoid concurrent deployment conflicts.
@batchSize(1)
resource deployments 'Microsoft.CognitiveServices/accounts/deployments@2026-03-01' = [
  for d in modelDeployments: {
    parent: foundry
    name: d.name
    sku: {
      name: 'GlobalStandard'
      capacity: d.capacity
    }
    properties: {
      model: {
        format: 'OpenAI'
        name: d.model
        version: d.version
      }
      versionUpgradeOption: 'NoAutoUpgrade'
    }
    dependsOn: [
      sharedProject
    ]
  }
]

// Create participant projects after the model deployments, one at a time, to avoid concurrent
// operations on the Foundry resource.
@batchSize(1)
resource participantProjects 'Microsoft.CognitiveServices/accounts/projects@2026-03-01' = [
  for name in participantProjectNames: {
    parent: foundry
    name: name
    location: location
    tags: tags
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      displayName: name
      description: 'Participant project for the Microsoft Foundry hands-on workshop.'
    }
    dependsOn: [
      deployments
    ]
  }
]

// ---------- Storage (knowledge source) ----------

resource storage 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' = {
  parent: storage
  name: 'default'
}

resource docsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  parent: blobService
  name: docsContainerName
}

// ---------- Azure AI Search ----------

// 2026-03-01-preview or later is required to set knowledgeRetrieval.
resource search 'Microsoft.Search/searchServices@2026-03-01-preview' = {
  name: searchName
  location: searchLocation
  tags: tags
  sku: {
    name: 'basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'Default'
    publicNetworkAccess: 'enabled'
    semanticSearch: 'standard'
    // Search REST API 2026-04-01+ bills agentic retrieval via knowledgeRetrieval, not semanticSearch.
    // The free plan returns a payment-required error once the monthly allowance is consumed.
    knowledgeRetrieval: 'standard'
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
  }
}

// ---------- Monitoring (tracing) ----------

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: logName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// ---------- RBAC: participants ----------

resource participantsFoundry 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployWorkshopRbac) {
  scope: foundry
  name: guid(foundry.id, participantsGroupObjectId, participantFoundryRole)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', participantFoundryRole)
    principalId: participantsGroupObjectId
    principalType: 'Group'
  }
}

resource participantsRgReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployWorkshopRbac) {
  name: guid(resourceGroup().id, participantsGroupObjectId, roleIds.reader)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.reader)
    principalId: participantsGroupObjectId
    principalType: 'Group'
  }
}

resource participantsSearchReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployWorkshopRbac) {
  scope: search
  name: guid(search.id, participantsGroupObjectId, roleIds.searchIndexDataReader)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.searchIndexDataReader)
    principalId: participantsGroupObjectId
    principalType: 'Group'
  }
}

resource participantsLogReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployWorkshopRbac) {
  scope: logAnalytics
  name: guid(logAnalytics.id, participantsGroupObjectId, roleIds.logAnalyticsReader)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.logAnalyticsReader)
    principalId: participantsGroupObjectId
    principalType: 'Group'
  }
}

// ---------- RBAC: instructor ----------

resource instructorFoundry 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployWorkshopRbac) {
  scope: foundry
  name: guid(foundry.id, instructorPrincipalId, roleIds.foundryOwner)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.foundryOwner)
    principalId: instructorPrincipalId
    principalType: instructorPrincipalType
  }
}

resource instructorSearchService 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployWorkshopRbac) {
  scope: search
  name: guid(search.id, instructorPrincipalId, roleIds.searchServiceContributor)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.searchServiceContributor)
    principalId: instructorPrincipalId
    principalType: instructorPrincipalType
  }
}

resource instructorSearchData 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployWorkshopRbac) {
  scope: search
  name: guid(search.id, instructorPrincipalId, roleIds.searchIndexDataContributor)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.searchIndexDataContributor)
    principalId: instructorPrincipalId
    principalType: instructorPrincipalType
  }
}

resource instructorBlob 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployWorkshopRbac) {
  scope: storage
  name: guid(storage.id, instructorPrincipalId, roleIds.storageBlobDataContributor)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.storageBlobDataContributor)
    principalId: instructorPrincipalId
    principalType: instructorPrincipalType
  }
}

// ---------- RBAC: managed identities ----------

resource searchToStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployWorkshopRbac) {
  scope: storage
  name: guid(storage.id, search.id, roleIds.storageBlobDataReader)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.storageBlobDataReader)
    principalId: search.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource searchToFoundry 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployWorkshopRbac) {
  scope: foundry
  name: guid(foundry.id, search.id, roleIds.cognitiveServicesUser)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.cognitiveServicesUser)
    principalId: search.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource sharedProjectToFoundry 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployWorkshopRbac) {
  scope: foundry
  name: guid(foundry.id, sharedProject.id, roleIds.foundryUser)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.foundryUser)
    principalId: sharedProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource sharedProjectToSearch 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployWorkshopRbac) {
  scope: search
  name: guid(search.id, sharedProject.id, roleIds.searchIndexDataReader)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.searchIndexDataReader)
    principalId: sharedProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource participantProjectsToFoundry 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (name, i) in participantProjectNames: if (deployWorkshopRbac) {
    scope: foundry
    name: guid(foundry.id, participantProjects[i].id, roleIds.foundryUser)
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.foundryUser)
      principalId: participantProjects[i].identity.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

resource participantProjectsToSearch 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (name, i) in participantProjectNames: if (deployWorkshopRbac) {
    scope: search
    name: guid(search.id, participantProjects[i].id, roleIds.searchIndexDataReader)
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.searchIndexDataReader)
      principalId: participantProjects[i].identity.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

// ---------- Outputs ----------

output foundryName string = foundry.name
output foundryEndpoint string = 'https://${foundry.name}.services.ai.azure.com'
output openAiEndpoint string = 'https://${foundry.name}.openai.azure.com'
output sharedProjectEndpoint string = 'https://${foundry.name}.services.ai.azure.com/api/projects/${sharedProject.name}'
output participantProjects array = [
  for (name, i) in participantProjectNames: {
    name: participantProjects[i].name
    endpoint: 'https://${foundry.name}.services.ai.azure.com/api/projects/${participantProjects[i].name}'
  }
]
output searchName string = search.name
output searchEndpoint string = 'https://${search.name}.search.windows.net'
output storageName string = storage.name
output storageResourceId string = storage.id
output docsContainerName string = docsContainer.name
output appInsightsName string = appInsights.name
