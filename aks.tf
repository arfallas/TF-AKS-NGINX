# Configure the Azure provider
provider "azurerm" {
  # The "feature" block is required for AzureRM provider 2.x. 
  # If you are using version 1.x, the "features" block is not allowed.
  version = "~>2.0"
  features {}
}

#Create the blob storage backend in Azure before running this
#Export access key and store in ARM_ACCESS_KEY
#This block cannot read from tfvars as this is assoicated with a provider

resource "azurerm_resource_group" "demo" {
  name     = "${var.prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "demo" {
  name                = "${var.prefix}-network"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "demo" {
  name                 = "${var.prefix}-subnet"
  virtual_network_name = azurerm_virtual_network.demo.name
  resource_group_name  = azurerm_resource_group.demo.name
  address_prefixes     = ["10.1.0.0/22"]
}

resource "azurerm_kubernetes_cluster" "demo" {
  name                = "${var.prefix}-aks"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  dns_prefix          = "${var.prefix}-aks"

  default_node_pool {
    name                = "default"
    node_count          = 1
    vm_size             = "Standard_D2_v2"
    type                = "VirtualMachineScaleSets"
    availability_zones  = ["1", "2"]
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 3

    # Required for advanced networking
    vnet_subnet_id = azurerm_subnet.demo.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    network_policy    = "calico"
  }

  tags = {
    Environment = "Development"
  }
}



data "azurerm_kubernetes_cluster" "credentials" {
  name                = azurerm_kubernetes_cluster.demo.name
  resource_group_name = azurerm_resource_group.demo.name
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.credentials.kube_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.cluster_ca_certificate)

  }
}

resource "helm_release" "nginx_ingress" {
  name = "nginx-ingress-controller"
  namespace = "default"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"
  values = [
    "${file("values.yaml")}"
  ]
  # set {
  #   name  = "service.type"
  #   value = "LoadBalancer"
  # }
}

#module "cert-manager" {
#  source  = "terraform-iaac/cert-manager/kubernetes"
#  version = "2.4.2"
#  # insert the 2 required variables here
#}


# data "kubernetes_service" "chartloadbalancer" {
#   metadata {
#     name = helm_release.nginx_ingress.name
#     namespace = helm_release.nginx_ingress.namespace
#   }
# }
