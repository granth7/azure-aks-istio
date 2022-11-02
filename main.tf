resource "azurerm_resource_group" "rg" {
  name     = "aks-resource-group"
  location = "centralus"
}

# Create the VNET
resource "azurerm_virtual_network" "hendertech-vnet" {
  name                = "${var.region}-${var.environment}-${var.app_name}-vnet"
  address_space       = ["10.10.0.0/16"]
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  tags = {
    environment = var.environment
  }
}

# Create a Gateway Subnet
resource "azurerm_subnet" "hendertech-gateway-subnet" {
  count                = var.vpnInstanceCount
  name                 = "GatewaySubnet" # do not rename
  address_prefixes     = ["10.10.0.0/24"]
  virtual_network_name = azurerm_virtual_network.hendertech-vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "aks-subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.hendertech-vnet.name
  address_prefixes     = ["10.10.16.0/20"]
  service_endpoints    = ["Microsoft.ContainerRegistry"]
}

resource "azuread_group" "aks-admin-group" {
  display_name         = "AKS-Aadmins"
  security_enabled = true
}

resource "azurerm_kubernetes_cluster" "aks" {
  count                = var.aksInstanceCount
  name                = "aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "hendertech-aks"
  default_node_pool {
    name                  = "default"
    vnet_subnet_id        = azurerm_subnet.aks-subnet.id
    type                  = "VirtualMachineScaleSets"
    enable_auto_scaling   = true
    enable_node_public_ip = false
    max_count             = 3
    min_count             = 1
    os_disk_size_gb       = 256
    vm_size               = "Standard_D2_v2"
  }
  azure_active_directory_role_based_access_control {
    managed                = true
    admin_group_object_ids = [azuread_group.aks-admin-group.id]
    azure_rbac_enabled     = true
  }
  identity {
    type = "SystemAssigned"
  }
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
  }
  
  azure_policy_enabled = true
  http_application_routing_enabled = true
}

################### Deploy Microsoft Container Registry  #######################################

resource "azurerm_container_registry" "hendertech-registry" {
  count               = var.aksInstanceCount
  name                = "hendertechRegistry"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_role_assignment" "hendertech-registry" {
  count                            = var.aksInstanceCount
  principal_id                     = azurerm_kubernetes_cluster.aks[0].kubelet_identity[0].object_id
  # OR principal_id                = data.azurerm_client_config.current.object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.hendertech-registry[0].id
  skip_service_principal_aad_check = true
}

###################Install Istio (Service Mesh) #######################################
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

data "azurerm_subscription" "current" {
}

resource "local_file" "kube_config" {
  count                = var.aksInstanceCount
  content    = azurerm_kubernetes_cluster.aks[0].kube_admin_config_raw
  filename   = "C:/Users/Grant/source/repos/azure-aks-istio/kube-cluster/config"   
}


resource "null_resource" "set-kube-config" {
  count                = var.aksInstanceCount
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    working_dir = "${path.module}"
    command = "az aks get-credentials -n ${azurerm_kubernetes_cluster.aks[0].name} -g ${azurerm_resource_group.rg.name} --file kube-cluster/${azurerm_kubernetes_cluster.aks[0].name} --admin --overwrite-existing"
  }
  depends_on = [local_file.kube_config]
}


resource "kubernetes_namespace" "istio_system" {
  count                = var.aksInstanceCount
  provider = kubernetes
  metadata {
    name = "istio-system"
  }
}

resource "kubernetes_secret" "grafana" {
  count                = var.aksInstanceCount
  provider = kubernetes
  metadata {
    name      = "grafana"
    namespace = "istio-system"
    labels = {
      app = "grafana"
    }
  }
  data = {
    username   = "admin"
    passphrase = random_password.password.result
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace.istio_system]
}

resource "kubernetes_secret" "kiali" {
  count                = var.aksInstanceCount
  provider = kubernetes
  metadata {
    name      = "kiali"
    namespace = "istio-system"
    labels = {
      app = "kiali"
    }
  }
  data = {
    username   = "admin"
    passphrase = random_password.password.result
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace.istio_system]
}

resource "local_file" "istio-config" {
  count                = var.aksInstanceCount
  content = templatefile("${path.module}/istio-aks.tmpl", {
    enableGrafana = true
    enableKiali   = true
    enableTracing = true
  })
  filename = ".istio/istio-aks.yaml"
}

resource "null_resource" "istio" {
  count                = var.aksInstanceCount
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "istioctl manifest apply -f .istio/istio-aks.yaml --skip-confirmation --kubeconfig kube-cluster/${azurerm_kubernetes_cluster.aks[0].name}"
    working_dir = "${path.module}"
  }
  depends_on = [kubernetes_secret.grafana, kubernetes_secret.kiali, local_file.istio-config]
}

resource "helm_release" "my-kubernetes-dashboard" {
  count                = var.vpnInstanceCount
  name = "my-kubernetes-dashboard"

  repository = "https://kubernetes.github.io/dashboard/"
  chart      = "kubernetes-dashboard"
  namespace  = "default"

  set {
    name  = "service.externalPort"
    value = 9090
  }

  set {
    name  = "replicaCount"
    value = 1
  }

  set {
    name  = "rbac.clusterReadOnlyRole"
    value = "true"
  }

  set {
    name  = "extraArgs"
    value = "{--enable-insecure-login=true,--insecure-bind-address=0.0.0.0,--insecure-port=9090}"
  }

  set {
    name  = "protocolHttp"
    value = true
  }
}

module "cert_manager" {
  count                = var.vpnInstanceCount
  create_namespace   = false
  namespace_name     = var.namespace
  source        = "terraform-iaac/cert-manager/kubernetes"

  cluster_issuer_email                   = var.email
  cluster_issuer_name                    = "cert-manager-global"
  cluster_issuer_private_key_secret_name = "cert-manager-private-key"


  solvers = [
  {
    dns01 = {
      cloudflare = {
        email = var.email
        apiKeySecretRef = {
          name = "cloudflare-api-key-secret"
          key  = "API"
        }
      },
    },
    selector = {
      dnsZones = [
        var.dnsZone
      ]
    }
  }
]
  certificates = {
  "letsencrypt-production-hendertech" = {
    dns_names = [var.dnsName]
    }
  }

  
}

################### Deploy yaml info sample application with gateway  #######################################

// kubectl provider can be installed from here - https://gavinbunney.github.io/terraform-provider-kubectl/docs/provider.html 
data "kubectl_filename_list" "manifests" {
    count = var.aksInstanceCount
    pattern = "samples/yaml/*.yaml"
}

resource "kubectl_manifest" "yaml" {
    count = var.aksInstanceCount > 0 ? length(data.kubectl_filename_list.manifests[0].matches) : 0
    yaml_body = var.aksInstanceCount > 0 ? file(element(data.kubectl_filename_list.manifests[0].matches, count.index)) : ""
}
