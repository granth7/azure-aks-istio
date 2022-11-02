
provider "kubernetes" {
  host                   = var.aksInstanceCount > 0 ? azurerm_kubernetes_cluster.aks[0].kube_admin_config.0.host : ""
  client_certificate     = var.aksInstanceCount > 0 ?"${base64decode(azurerm_kubernetes_cluster.aks[0].kube_admin_config.0.client_certificate)}" : ""
  client_key             = var.aksInstanceCount > 0 ?"${base64decode(azurerm_kubernetes_cluster.aks[0].kube_admin_config.0.client_key)}" : ""
  cluster_ca_certificate = var.aksInstanceCount > 0 ?"${base64decode(azurerm_kubernetes_cluster.aks[0].kube_admin_config.0.cluster_ca_certificate)}" : ""
}

provider "kubectl" {
  host                   = var.aksInstanceCount > 0 ? azurerm_kubernetes_cluster.aks[0].kube_admin_config.0.host : ""
  client_certificate     = var.aksInstanceCount > 0 ? "${base64decode(azurerm_kubernetes_cluster.aks[0].kube_admin_config.0.client_certificate)}" : ""
  client_key             = var.aksInstanceCount > 0 ? "${base64decode(azurerm_kubernetes_cluster.aks[0].kube_admin_config.0.client_key)}" : ""
  cluster_ca_certificate = var.aksInstanceCount > 0 ? "${base64decode(azurerm_kubernetes_cluster.aks[0].kube_admin_config.0.cluster_ca_certificate)}" : ""
  config_path            = "./kube-cluster/aks"
  config_context         = "aks-admin"
}

provider "helm" {
  kubernetes {
    host                   = var.aksInstanceCount > 0 ? azurerm_kubernetes_cluster.aks[0].kube_admin_config.0.host : ""
    client_certificate     = var.aksInstanceCount > 0 ? "${base64decode(azurerm_kubernetes_cluster.aks[0].kube_admin_config.0.client_certificate)}" : ""
    client_key             = var.aksInstanceCount > 0 ? "${base64decode(azurerm_kubernetes_cluster.aks[0].kube_admin_config.0.client_key)}" : ""
    cluster_ca_certificate = var.aksInstanceCount > 0 ? "${base64decode(azurerm_kubernetes_cluster.aks[0].kube_admin_config.0.cluster_ca_certificate)}" : ""
  }
}

provider "azurerm" {
  features {}
}
