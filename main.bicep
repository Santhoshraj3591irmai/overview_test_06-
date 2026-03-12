// Main orchestration template for IRMAI Azure infrastructure
// This template deploys a complete isolated workspace (Resource Group) for a client
// Each deployment creates a new isolated environment with identical topology

@description('Environment name (e.g., uat, prod, dev)')
param environment string = 'uat'

@description('Client identifier (e.g., client1, client2, or specific client name)')
param clientName string

@description('Azure region for resource deployment')
param location string = resourceGroup().location

@description('Azure subscription ID')
param subscriptionId string = subscription().subscriptionId

@description('Common tags to apply to all resources')
param tags object = {
  Environment: environment
  Client: clientName
  ManagedBy: 'IaC'
  CreatedDate: utcNow('yyyy-MM-dd')
}

// Helper variables for naming convention
var resourcePrefix = 'irmai-${toLower(environment)}-${toLower(clientName)}'
var resourceGroupName = 'RG-IRMAI-${toUpper(environment)}-${toUpper(clientName)}-${replace(toLower(location), ' ', '')}'

// Module: Network infrastructure
// Deploys virtual networks, subnets, network security groups, and related networking resources
module networkModule 'modules/network.bicep' = {
  name: 'network-deployment'
  params: {
    resourcePrefix: resourcePrefix
    location: location
    tags: tags
    environment: environment
    clientName: clientName
  }
}

// Module: Compute resources
// Deploys App Services, AKS clusters, Container Apps, VMs, and other compute resources
module computeModule 'modules/compute.bicep' = {
  name: 'compute-deployment'
  params: {
    resourcePrefix: resourcePrefix
    location: location
    tags: tags
    environment: environment
    clientName: clientName
    subscriptionId: subscriptionId
  }
  dependsOn: [
    networkModule
  ]
}

// Module: Data resources
// Deploys SQL databases, Cosmos DB, Storage accounts, and other data storage resources
module dataModule 'modules/data.bicep' = {
  name: 'data-deployment'
  params: {
    resourcePrefix: resourcePrefix
    location: location
    tags: tags
    environment: environment
    clientName: clientName
  }
  dependsOn: [
    networkModule
  ]
}

// Module: Security resources
// Deploys Key Vaults, managed identities, RBAC assignments, and security configurations
module securityModule 'modules/security.bicep' = {
  name: 'security-deployment'
  params: {
    resourcePrefix: resourcePrefix
    location: location
    tags: tags
    environment: environment
    clientName: clientName
    subscriptionId: subscriptionId
  }
  dependsOn: [
    networkModule
    computeModule
    dataModule
  ]
}

// Module: Monitoring and observability
// Deploys Application Insights, Log Analytics workspaces, and monitoring configurations
module monitoringModule 'modules/monitoring.bicep' = {
  name: 'monitoring-deployment'
  params: {
    resourcePrefix: resourcePrefix
    location: location
    tags: tags
    environment: environment
    clientName: clientName
  }
  dependsOn: [
    computeModule
    dataModule
  ]
}

// Outputs: Critical resource information for reference and integration
output resourceGroupName string = resourceGroupName
output resourcePrefix string = resourcePrefix
output location string = location
output environment string = environment
output clientName string = clientName

// Network outputs (populated by network module)
output networkOutputs object = networkModule.outputs

// Compute outputs (populated by compute module)
output computeOutputs object = computeModule.outputs

// Data outputs (populated by data module)
output dataOutputs object = dataModule.outputs

// Security outputs (populated by security module)
output securityOutputs object = securityModule.outputs

// Monitoring outputs (populated by monitoring module)
output monitoringOutputs object = monitoringModule.outputs
