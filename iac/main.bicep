@description('Deployment prefix used to generate all resource names. Choose a short, lowercase alphanumeric string.')
@minLength(3)
@maxLength(10)
param prefix string

@description('Deployment environment. Drives resource naming and tag values.')
@allowed(['lab', 'prod'])
param environment string = 'lab'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('HIPAA compliance tags applied to all resources.')
param tags object = {
  DataClassification: 'PHI'
  ComplianceFramework: 'HIPAA'
  Environment: environment
  Owner: 'pipeline-operator'
}

// --- Resource name variables (prefix-driven, no hardcoded names) ---
var logAnalyticsName = '${prefix}-law-${environment}'
var serviceBusNamespaceName = '${prefix}-sb-${environment}'
var keyVaultName = '${prefix}-kv-${environment}'
var functionAppName = '${prefix}-func-validate-${environment}'
var storageAccountName = '${prefix}st${environment}'
var appServicePlanName = '${prefix}-asp-${environment}'

// --- Modules ---

module logAnalytics 'modules/loganalytics.bicep' = {
  name: 'deploy-loganalytics'
  params: {
    name: logAnalyticsName
    location: location
    tags: tags
  }
}

module serviceBus 'modules/servicebus.bicep' = {
  name: 'deploy-servicebus'
  params: {
    namespaceName: serviceBusNamespaceName
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

module keyVault 'modules/keyvault.bicep' = {
  name: 'deploy-keyvault'
  params: {
    name: keyVaultName
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

module functionApp 'modules/functionapp.bicep' = {
  name: 'deploy-functionapp'
  params: {
    functionAppName: functionAppName
    storageAccountName: storageAccountName
    appServicePlanName: appServicePlanName
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

// --- Outputs ---
output logAnalyticsWorkspaceId string = logAnalytics.outputs.workspaceId
output serviceBusNamespaceId string = serviceBus.outputs.namespaceId
output keyVaultUri string = keyVault.outputs.vaultUri
output functionAppId string = functionApp.outputs.functionAppId

@description('Deploy AHDS workspace and FHIR service separately. See docs/deployment-guide.md for manual provisioning steps. AHDS workspace names require lowercase alphanumeric only.')
output note string = 'AHDS FHIR service requires manual provisioning. See deployment-guide.md.'
