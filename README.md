# overview_test_06-\\\
inbuild files main.bicep & prod.json & uat.json

main.bicep 

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

prod.json

{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": {
      "value": "prod"
    },
    "clientName": {
      "value": "client1"
    },
    "location": {
      "value": "eastus"
    },
    "subscriptionId": {
      "value": ""
    },
    "tags": {
      "value": {
        "Environment": "prod",
        "Client": "client1",
        "ManagedBy": "IaC",
        "Purpose": "Production",
        "Criticality": "High"
      }
    }
  },
  "metadata": {
    "description": "Parameters for Production environment deployment. Use higher SKU tiers and production-grade settings. Update clientName for each new production client."
  }
}

uat.json

{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": {
      "value": "uat"
    },
    "clientName": {
      "value": "client1"
    },
    "location": {
      "value": "eastus"
    },
    "subscriptionId": {
      "value": ""
    },
    "tags": {
      "value": {
        "Environment": "uat",
        "Client": "client1",
        "ManagedBy": "IaC",
        "Purpose": "User Acceptance Testing"
      }
    }
  },
  "metadata": {
    "description": "Parameters for UAT environment deployment. This matches the existing RG-IRMAI-UAT-US-1 resource group configuration."
  }
}

--------------------------------------------------------

After adding the all resources updated file 

1 main.bicep
2 kubernetes-resources.bicep
3 prod.json
4 uat.json

kubernetes-resources.bicep 

$  cat kubernetes-resources.bicep
// kubernetes-resources.bicep
param environment string
param rbacData array
param ingressData array
param serviceData array
param serviceAccountData array

// 1. Roles
resource k8sRoles 'rbac.authorization.k8s.io/Role@v1' = [for rbac in rbacData: {
  metadata: { name: rbac.roleName, namespace: rbac.ns }
  rules: rbac.rules
}]

// 2. RoleBindings
resource k8sRoleBindings 'rbac.authorization.k8s.io/RoleBinding@v1' = [for rbac in rbacData: {
  metadata: { name: '${rbac.roleName}-binding', namespace: rbac.ns }
  subjects: [{ kind: 'ServiceAccount', name: rbac.saName, namespace: rbac.ns }]
  roleRef: { kind: 'Role', name: rbac.roleName, apiGroup: 'rbac.authorization.k8s.io' }
  dependsOn: [ k8sRoles ]
}]

// 3. Ingresses
resource k8sIngresses 'networking.k8s.io/Ingress@v1' = [for ing in ingressData: {
  metadata: { name: ing.name, namespace: ing.ns }
  spec: {
    ingressClassName: 'nginx'
    rules: [{
      http: {
        paths: [{
          path: '/'
          pathType: 'Prefix'
          backend: { service: { name: 'backend-service', port: { number: 80 } } }
        }]
      }
    }]
  }
}]

// 4. Services (The loop for your 21 services)
resource k8sAppServices 'core/v1/Service@v1' = [for svc in serviceData: {
  metadata: { name: svc.name, namespace: svc.ns }
  spec: {
    type: 'ClusterIP'
    ports: [{ port: 80, targetPort: 80, protocol: 'TCP' }]
    selector: { app: svc.name }
  }
}]

// 5. Service Accounts (The loop for your 26 SAs)
resource k8sServiceAccounts 'core/v1/ServiceAccount@v1' = [for sa in serviceAccountData: {
  metadata: {
    name: sa.name
    namespace: sa.ns
    labels: { managedBy: 'bicep', environment: environment }
  }
}]

// 6. Persistent Volume Claims (PVCs)
param pvcData array = [] // Default to empty if not provided

resource k8sPvcs 'core/v1/PersistentVolumeClaim@v1' = [for pvc in pvcData: {
  metadata: {
    name: pvc.name
    namespace: pvc.ns
  }
  spec: {
    accessModes: [
      pvc.accessMode // e.g., 'ReadWriteOnce' or 'ReadWriteMany'
    ]
    resources: {
      requests: {
        storage: pvc.size // e.g., '10Gi'
      }
    }
    // Optional: storageClassName: 'managed-csi'
  }
}]

// 7. Secrets
param secretData array = [] // Default to empty if not provided

resource k8sSecrets 'core/v1/Secret@v1' = [for secret in secretData: {
  metadata: {
    name: secret.name
    namespace: secret.ns
  }
  type: 'Opaque' // Standard type for app secrets
  data: secret.?value ?? {} // Uses a placeholder if no value is provided
}]


// 8. ConfigMaps
param configMapData array = [] // Default to empty if not provided

resource k8sConfigMaps 'core/v1/ConfigMap@v1' = [for cm in configMapData: {
  metadata: {
    name: cm.name
    namespace: cm.ns
  }
  // Optional: Add default data or placeholder to prevent deployment failure
  data: cm.?data ?? { 'config.placeholder': 'true' }
}]


// 9. Deployments
param deploymentData array = []

resource k8sDeployments 'apps/v1/Deployment@v1' = [for deploy in deploymentData: {
  metadata: {
    name: deploy.name
    namespace: deploy.ns
    labels: { app: deploy.name }
  }
  spec: {
    replicas: deploy.?replicas ?? 1
    selector: { matchLabels: { app: deploy.name } }
    template: {
      metadata: { labels: { app: deploy.name } }
      spec: {
        serviceAccountName: deploy.?saName ?? 'default'
        containers: [
          {
            name: deploy.name
            image: deploy.?image ?? 'mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine' // Placeholder image
            ports: [{ containerPort: deploy.?port ?? 80 }]
          }
        ]
      }
    }
  }
}]

main.bicep

 cat main.bicep
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

@description('Name of the existing AKS cluster for RBAC configuration')
param clusterName string

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

// Reference existing AKS to pull credentials for the Kubernetes extension
resource aks 'Microsoft.ContainerService/managedClusters@2024-02-01' existing = {
  name: clusterName
}


// 1. Import Kubernetes extension using the existing cluster's credentials
extension kubernetes with {
  kubeConfig: aks.listClusterAdminCredential().kubeconfigs[0].value
  namespace: 'default'
}

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


// --- DATA CONFIGURATION ---
var rbacData = [
  {
    ns: 'airbyte'
    roleName: 'airbyte-admin-role'
    saName: 'airbyte-admin'
    rules: [
      {
        apiGroups: ['']
        resources: ['pods', 'jobs', 'pods/log']
        verbs: ['get', 'list', 'watch', 'create', 'delete']
      }
    ]
  }
  {
    ns: 'cert-manager'
    roleName: 'cert-manager-webhook:dynamic-serving'
    saName: 'cert-manager-webhook'
    rules: [
      {
        apiGroups: ['']
        resources: ['secrets']
        verbs: ['get', 'list', 'watch', 'update']
      }
    ]
  }
  {
    ns: 'ingress-nginx'
    roleName: 'ingress-nginx'
    saName: 'ingress-nginx'
    rules: [
      {
        apiGroups: ['']
        resources: ['configmaps', 'endpoints', 'nodes', 'pods', 'secrets']
        verbs: ['get', 'list', 'watch']
      }
    ]
  }
]


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


// --- UPDATED INGRESS & K8S RESOURCES ---

// List of Ingresses (Resources 1-2)
var ingressData = [
  {
    name: 'fastapi-outlier-ingress'
    ns: 'clickhouse-pvc'
  }
  {
    name: 'gremlin-tools-ingress'
    ns: 'gremlin-tools'
  }

]


// =================================================================
// PRODUCTION APPLICATION SERVICES (21 RESOURCES)
// =================================================================

var serviceData = [
  { ns: 'airflow', name: 'airflow-cluster' }
  { ns: 'cert-manager', name: 'cert-manager' }
  { ns: 'cert-manager', name: 'cert-manager-webhook' }
  { ns: 'clickhouse', name: 'clickhouse-service' }
  { ns: 'clickhouse', name: 'outlier-analysis-service' }
  { ns: 'clickhouse-pvc', name: 'clickhouse-service' }
  { ns: 'clickhouse-pvc', name: 'fastapi-outlier-service-v2' }
  { ns: 'clickhouse-pvc', name: 'fastapi-outlier-v2' }
  { ns: 'clickhouse-pvc', name: 'outlier-analysis-service' }
  { ns: 'gremlin-tools', name: 'gremlin-tools' }
  { ns: 'ingress-nginx', name: 'ingress-nginx-controller' }
  { ns: 'ingress-nginx', name: 'ingress-nginx-controller-admission' }
  { ns: 'irmai-ccm-layered-analysis', name: 'irmai-ccm-layered-analysis-service' }
  { ns: 'irmai-ccm-outlier-analysis', name: 'irmai-ccm-outlier-analysis-service' }
  { ns: 'irmai-genui', name: 'irmai-genui-service' }
  { ns: 'irmai-irmai-ocpm-v1', name: 'irmai-irmai-ocpm-v1-service' }
  { ns: 'irmai-irmai-planning-agent-v3', name: 'irmai-irmai-planning-agent-v3-service' }
  { ns: 'irmai-kg', name: 'irmai-kg-v1' }
  { ns: 'mvp', name: 'clickhouse-udf' }
  { ns: 'outlier-analysis-ns', name: 'outlier-analysis-service' }
  { ns: 'qdrant', name: 'qdrant-cluster' }
]


// =================================================================
// SERVICE ACCOUNTS DEPLOYMENT
// =================================================================

var serviceAccountData = [
  { ns: 'airbyte', name: 'airbyte-admin' }
  { ns: 'cert-manager', name: 'cert-manager' }
  { ns: 'cert-manager', name: 'cert-manager-cainjector' }
  { ns: 'cert-manager', name: 'cert-manager-webhook' }
  { ns: 'clickhouse-pvc', name: 'clickhouse-prod' }
  { ns: 'ingress-nginx', name: 'ingress-nginx' }
  // Namespaces where only the 'default' SA is needed
  { ns: 'cert-manager', name: 'default' }
  { ns: 'clickhouse', name: 'default' }
  { ns: 'clickhouse-pvc', name: 'default' }
  { ns: 'gremlin-tools', name: 'default' }
  { ns: 'ingress-nginx', name: 'default' }
  { ns: 'irmai-ccm-layered-analysis', name: 'default' }
  { ns: 'irmai-ccm-outlier-analysis', name: 'default' }
  { ns: 'irmai-clickhouse-files-update', name: 'default' }
  { ns: 'irmai-genui', name: 'default' }
  { ns: 'irmai-irmai-ocpm-v1', name: 'default' }
  { ns: 'irmai-irmai-planning-agent-v3', name: 'default' }
  { ns: 'irmai-kg', name: 'default' }
  { ns: 'mongodb', name: 'default' }
  { ns: 'mvp', name: 'default' }
  { ns: 'nemo', name: 'default' }
  { ns: 'neo4j', name: 'default' }
  { ns: 'outlier-analysis-ns', name: 'default' }
  { ns: 'qdrant', name: 'default' }
  { ns: 'sentry', name: 'default' }
  { ns: 'test-auto-create', name: 'default' }
]

// =================================================================
// PERSISTENT VOLUME CLAIMS CONFIGURATION (13 RESOURCES)
// =================================================================
var pvcData = [
  { ns: 'airbyte', name: 'airbyte-minio-pv-claim-airbyte-minio-0', size: '20Gi', accessMode: 'ReadWriteOnce' }
  { ns: 'airbyte', name: 'airbyte-volume-db-airbyte-db-0', size: '10Gi', accessMode: 'ReadWriteOnce' }
  { ns: 'clickhouse', name: 'clickhouse-storage-clickhouse-0', size: '50Gi', accessMode: 'ReadWriteOnce' }
  { ns: 'clickhouse', name: 'data-my-clickhouse-0', size: '50Gi', accessMode: 'ReadWriteOnce' }
  { ns: 'clickhouse-pvc', name: 'clickhouse-shared-volume-rwx', size: '100Gi', accessMode: 'ReadWriteMany' }
  { ns: 'clickhouse-pvc', name: 'clickhouse-storage-clickhouse-0', size: '50Gi', accessMode: 'ReadWriteOnce' }
  { ns: 'clickhouse-pvc', name: 'clickhouse-storage-clickhouse-prod-shard0-0', size: '50Gi', accessMode: 'ReadWriteOnce' }
  { ns: 'clickhouse-pvc', name: 'clickhouse-storage-clickhouse-prod-shard0-fixed-0', size: '50Gi', accessMode: 'ReadWriteOnce' }
  { ns: 'clickhouse-pvc', name: 'data-clickhouse-prod-shard0-0', size: '50Gi', accessMode: 'ReadWriteOnce' }
  { ns: 'mongodb', name: 'data-my-mongodb-0', size: '20Gi', accessMode: 'ReadWriteOnce' }
  { ns: 'neo4j', name: 'data-my-neo4j-0', size: '20Gi', accessMode: 'ReadWriteOnce' }
  { ns: 'outlier-analysis-ns', name: 'clickhouse-storage-clickhouse-0', size: '50Gi', accessMode: 'ReadWriteOnce' }
  { ns: 'sentry', name: 'sentry-postgres-pvc', size: '20Gi', accessMode: 'ReadWriteOnce' }
]

// =================================================================
// KUBERNETES SECRETS CONFIGURATION (51 RESOURCES)
// =================================================================
var secretData = [
  // Airbyte & Cert-Manager
  { ns: 'airbyte', name: 'airbyte-airbyte-secrets' }
  { ns: 'airbyte', name: 'airbyte-gcs-log-creds' }
  { ns: 'cert-manager', name: 'cert-manager-webhook-ca' }
  { ns: 'cert-manager', name: 'letsencrypt-prod' }
  { ns: 'cert-manager', name: 'letsencrypt-staging' }

  // Clickhouse & Nginx
  { ns: 'clickhouse', name: 'clickhouse-prod' }
  { ns: 'clickhouse-pvc', name: 'acr-secret' }
  { ns: 'clickhouse-pvc', name: 'clickhouse-prod' }
  { ns: 'gremlin-tools', name: 'acr-secret' }
  { ns: 'gremlin-tools', name: 'gremlin-tools-tls' }
  { ns: 'ingress-nginx', name: 'ingress-nginx-admission' }
  { ns: 'ingress-nginx', name: 'sh.helm.release.v1.ingress-nginx.v1' }

  // App Specific Secrets
  { ns: 'irmai-ccm-layered-analysis', name: 'ccm-layered-analysis-app-secrets' }
  { ns: 'irmai-ccm-outlier-analysis', name: 'ccm-outlier-analysis-app-secrets' }
  { ns: 'irmai-clickhouse-files-update', name: 'clickhouse-files-update-app-secrets' }
  { ns: 'irmai-genui', name: 'genui-app-secrets' }
  { ns: 'irmai-irmai-ocpm-v1', name: 'azure-storage-account-f83aed6e9701540f39406cc-secret' }
  { ns: 'irmai-irmai-planning-agent-v3', name: 'irmai-planning-agent-v3-app-secrets' }
  { ns: 'irmai-kg', name: 'acr-secret' }

  // Helm Release Tracking Secrets (irmai-kg)
  { ns: 'irmai-kg', name: 'sh.helm.release.v1.irmai-kg-v1-306d4fb.v1' }
  { ns: 'irmai-kg', name: 'sh.helm.release.v1.irmai-kg-v1-531d7ae.v1' }
  { ns: 'irmai-kg', name: 'sh.helm.release.v1.irmai-kg-v1-5545758.v1' }
  { ns: 'irmai-kg', name: 'sh.helm.release.v1.irmai-kg-v1-c2fc774.v1' }
  { ns: 'irmai-kg', name: 'sh.helm.release.v1.irmai-kg-v1-e115bee.v1' }
  { ns: 'irmai-kg', name: 'sh.helm.release.v1.irmai-kg-v1-main-irmai-kg.v26' }
  { ns: 'irmai-kg', name: 'sh.helm.release.v1.irmai-kg-v1-main-irmai-kg.v27' }
  { ns: 'irmai-kg', name: 'sh.helm.release.v1.irmai-kg-v1-main-irmai-kg.v28' }
  { ns: 'irmai-kg', name: 'sh.helm.release.v1.irmai-kg-v1-main-irmai-kg.v29' }
  { ns: 'irmai-kg', name: 'sh.helm.release.v1.irmai-kg-v1-main-irmai-kg.v30' }

  // MVP Helm & App Secrets
  { ns: 'mvp', name: 'acr-secret' }
  { ns: 'mvp', name: 'sh.helm.release.v1.ccm-outlier-analysis-main-mvp.v31' }
  { ns: 'mvp', name: 'sh.helm.release.v1.ccm-outlier-analysis-main-mvp.v32' }
  { ns: 'mvp', name: 'sh.helm.release.v1.ccm-outlier-analysis-main-mvp.v33' }
  { ns: 'mvp', name: 'sh.helm.release.v1.ccm-outlier-analysis-main-mvp.v34' }
  { ns: 'mvp', name: 'sh.helm.release.v1.ccm-outlier-analysis-main-mvp.v35' }
  { ns: 'mvp', name: 'sh.helm.release.v1.clickhouse-udf-main-mvp.v34' }
  { ns: 'mvp', name: 'sh.helm.release.v1.clickhouse-udf-main-mvp.v35' }
  { ns: 'mvp', name: 'sh.helm.release.v1.clickhouse-udf-main-mvp.v36' }
  { ns: 'mvp', name: 'sh.helm.release.v1.clickhouse-udf-main-mvp.v37' }
  { ns: 'mvp', name: 'sh.helm.release.v1.clickhouse-udf-main-mvp.v38' }
  { ns: 'mvp', name: 'sh.helm.release.v1.genui-main-mvp.v36' }
  { ns: 'mvp', name: 'sh.helm.release.v1.genui-main-mvp.v37' }
  { ns: 'mvp', name: 'sh.helm.release.v1.genui-main-mvp.v38' }
  { ns: 'mvp', name: 'sh.helm.release.v1.genui-main-mvp.v39' }
  { ns: 'mvp', name: 'sh.helm.release.v1.genui-main-mvp.v40' }
  { ns: 'mvp', name: 'sh.helm.release.v1.irmai-planning-agent-v3-main-mvp.v32' }
  { ns: 'mvp', name: 'sh.helm.release.v1.irmai-planning-agent-v3-main-mvp.v33' }
  { ns: 'mvp', name: 'sh.helm.release.v1.irmai-planning-agent-v3-main-mvp.v34' }
  { ns: 'mvp', name: 'sh.helm.release.v1.irmai-planning-agent-v3-main-mvp.v35' }
  { ns: 'mvp', name: 'sh.helm.release.v1.irmai-planning-agent-v3-main-mvp.v36' }

  // Nemo
  { ns: 'nemo', name: 'ngc-secret' }
]


// =================================================================
// KUBERNETES CONFIGMAPS CONFIGURATION (33 RESOURCES)
// =================================================================
var configMapData = [
  // Specialized App Configs
  { ns: 'airbyte', name: 'airbyte-airbyte-env' }
  { ns: 'airbyte', name: 'airbyte-airbyte-yml' }
  { ns: 'airbyte', name: 'airbyte-pod-sweeper-sweep-pod-script' }
  { ns: 'airbyte', name: 'airbyte-temporal-dynamicconfig' }
  { ns: 'airflow', name: 'airflow-cluster-config' }
  { ns: 'clickhouse', name: 'my-clickhouse-users-config' }
  { ns: 'clickhouse-pvc', name: 'clickhouse-auth-override' }
  { ns: 'clickhouse-pvc', name: 'clickhouse-listen-all' }
  { ns: 'clickhouse-pvc', name: 'clickhouse-prod-configd' }
  { ns: 'ingress-nginx', name: 'ingress-nginx-controller' }
  { ns: 'qdrant', name: 'qdrant-cluster-config' }
  { ns: 'sentry', name: 'sentry-env' }

  // kube-root-ca.crt for all namespaces
  { ns: 'airflow', name: 'kube-root-ca.crt' }
  { ns: 'cert-manager', name: 'kube-root-ca.crt' }
  { ns: 'clickhouse', name: 'kube-root-ca.crt' }
  { ns: 'clickhouse-pvc', name: 'kube-root-ca.crt' }
  { ns: 'gremlin-tools', name: 'kube-root-ca.crt' }
  { ns: 'ingress-nginx', name: 'kube-root-ca.crt' }
  { ns: 'irmai-ccm-layered-analysis', name: 'kube-root-ca.crt' }
  { ns: 'irmai-ccm-outlier-analysis', name: 'kube-root-ca.crt' }
  { ns: 'irmai-clickhouse-files-update', name: 'kube-root-ca.crt' }
  { ns: 'irmai-genui', name: 'kube-root-ca.crt' }
  { ns: 'irmai-irmai-ocpm-v1', name: 'kube-root-ca.crt' }
  { ns: 'irmai-irmai-planning-agent-v3', name: 'kube-root-ca.crt' }
  { ns: 'irmai-kg', name: 'kube-root-ca.crt' }
  { ns: 'mongodb', name: 'kube-root-ca.crt' }
  { ns: 'mvp', name: 'kube-root-ca.crt' }
  { ns: 'nemo', name: 'kube-root-ca.crt' }
  { ns: 'neo4j', name: 'kube-root-ca.crt' }
  { ns: 'outlier-analysis-ns', name: 'kube-root-ca.crt' }
  { ns: 'qdrant', name: 'kube-root-ca.crt' }
  { ns: 'sentry', name: 'kube-root-ca.crt' }
  { ns: 'test-auto-create', name: 'kube-root-ca.crt' }
]

// =================================================================
// KUBERNETES DEPLOYMENTS CONFIGURATION (51 RESOURCES)
// =================================================================
var deploymentData = [
  // Airbyte
  { ns: 'airbyte', name: 'airbyte-airbyte-api-server' }
  { ns: 'airbyte', name: 'airbyte-connector-builder-server' }
  { ns: 'airbyte', name: 'airbyte-cron' }
  { ns: 'airbyte', name: 'airbyte-pod-sweeper-pod-sweeper' }
  { ns: 'airbyte', name: 'airbyte-server' }
  { ns: 'airbyte', name: 'airbyte-temporal' }
  { ns: 'airbyte', name: 'airbyte-webapp' }
  { ns: 'airbyte', name: 'airbyte-worker' }
  // Airflow & Cert-Manager
  { ns: 'airflow', name: 'airflow-cluster' }
  { ns: 'cert-manager', name: 'cert-manager' }
  { ns: 'cert-manager', name: 'cert-manager-cainjector' }
  { ns: 'cert-manager', name: 'cert-manager-webhook' }
  // Clickhouse
  { ns: 'clickhouse', name: 'outlier-analysis-deployment' }
  { ns: 'clickhouse-pvc', name: 'fastapi-outlier-v2' }
  { ns: 'clickhouse-pvc', name: 'irmai-irmai-ocpm-v1-deployment' }
  { ns: 'clickhouse-pvc', name: 'outlier-analysis-deployment' }
  // IRMAI App Deployments
  { ns: 'gremlin-tools', name: 'gremlin-tools' }
  { ns: 'ingress-nginx', name: 'ingress-nginx-controller' }
  { ns: 'irmai-ccm-layered-analysis', name: 'irmai-ccm-layered-analysis-deployment' }
  { ns: 'irmai-ccm-outlier-analysis', name: 'irmai-ccm-outlier-analysis-deployment' }
  { ns: 'irmai-clickhouse-files-update', name: 'irmai-clickhouse-files-update-deployment' }
  { ns: 'irmai-genui', name: 'irmai-genui-deployment' }
  { ns: 'irmai-irmai-ocpm-v1', name: 'irmai-irmai-ocpm-v1-deployment' }
  { ns: 'irmai-irmai-planning-agent-v3', name: 'irmai-irmai-planning-agent-v3-deployment' }
  // IRMAI KG Releases
  { ns: 'irmai-kg', name: 'irmai-kg-v1' }
  { ns: 'irmai-kg', name: 'irmai-kg-v1-306d4fb' }
  { ns: 'irmai-kg', name: 'irmai-kg-v1-531d7ae' }
  { ns: 'irmai-kg', name: 'irmai-kg-v1-5545758' }
  { ns: 'irmai-kg', name: 'irmai-kg-v1-c2fc774' }
  { ns: 'irmai-kg', name: 'irmai-kg-v1-e115bee' }
  { ns: 'irmai-kg', name: 'irmai-kg-v1-main-irmai-kg' }
  // MVP Apps
  { ns: 'mvp', name: 'ccm-outlier-analysis' }
  { ns: 'mvp', name: 'ccm-outlier-analysis-main-mvp' }
  { ns: 'mvp', name: 'clickhouse-udf' }
  { ns: 'mvp', name: 'clickhouse-udf-main-mvp' }
  { ns: 'mvp', name: 'genui' }
  { ns: 'mvp', name: 'genui-main-mvp' }
  { ns: 'mvp', name: 'irmai-planning-agent-v3' }
  { ns: 'mvp', name: 'irmai-planning-agent-v3-main-mvp' }
  // Storage & Core NS
  { ns: 'outlier-analysis-ns', name: 'outlier-analysis-deployment' }
  { ns: 'qdrant', name: 'qdrant-cluster' }
  { ns: 'sentry', name: 'sentry-postgres' }
  { ns: 'sentry', name: 'sentry-redis' }
  { ns: 'sentry', name: 'sentry-web' }
  { ns: 'test-auto-create', name: 'testapp' }
]


// =================================================================
// KUBERNETES MODULE CALL
// =================================================================

module k8sDeployment './kubernetes-resources.bicep' = {
  name: 'k8s-client-infra-deployment'
  params: {
    environment: environment
    rbacData: rbacData
    ingressData: ingressData
    serviceData: serviceData
    serviceAccountData: serviceAccountData
    pvcData: pvcData
    secretData: secretData
    configMapData: configMapData
    deploymentData: deploymentData
  }
}

uat.json

$  cat uat.json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": {
      "value": "uat"
    },
    "clientName": {
      "value": "client1"
    },
    "location": {
      "value": "eastus"
    },
    "clusterName": {
      "value": "rg-irmai-uat-us-1"
    },
    "subscriptionId": {
      "value": "36448a90-905c-4f48-b1b3-deb171f7c247"
    },
    "tags": {
      "value": {
        "Environment": "uat",
        "Client": "client1",
        "ManagedBy": "IaC",
        "Purpose": "User Acceptance Testing"
      }
    }
  },
  "metadata": {
    "description": "Parameters for UAT environment deployment. This matches the existing RG-IRMAI-UAT-US-1 resource group configuration."
  }
}

prod.json

 cat prod.json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": {
      "value": "prod"
    },
    "clientName": {
      "value": "client1"
    },
    "location": {
      "value": "eastus"
    },
    "clusterName": {
      "value": "rg-irmai-prod-us-1"
    },
    "subscriptionId": {
      "value": "36448a90-905c-4f48-b1b3-deb171f7c247"
    },
    "tags": {
      "value": {
        "Environment": "prod",
        "Client": "client1",
        "ManagedBy": "IaC",
        "Purpose": "Production",
        "Criticality": "High"
      }
    }
  },
  "metadata": {
    "description": "Parameters for Production environment deployment. Use higher SKU tiers and production-grade settings. Update clientName for each new production client."
  }
}





