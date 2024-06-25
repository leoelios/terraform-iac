provider "vultr" {
  api_key = var.vultr_api_key
}

resource "vultr_kubernetes" "k8" {
  region  = "sao"
  label   = "vke-test"
  version = "v1.30.0+1"

  node_pools {
    node_quantity = 2
    plan          = "vc2-2c-4gb-sc1"
    label         = "vke-nodepool"
    auto_scaler   = true
    min_nodes     = 1
    max_nodes     = 3
  }
}

provider "kubernetes" {
  host = "https://${vultr_kubernetes.k8.endpoint}:6443"

  client_certificate     = base64decode(vultr_kubernetes.k8.client_certificate)
  client_key             = base64decode(vultr_kubernetes.k8.client_key)
  cluster_ca_certificate = base64decode(vultr_kubernetes.k8.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host = "https://${vultr_kubernetes.k8.endpoint}:6443"

    client_certificate     = base64decode(vultr_kubernetes.k8.client_certificate)
    client_key             = base64decode(vultr_kubernetes.k8.client_key)
    cluster_ca_certificate = base64decode(vultr_kubernetes.k8.cluster_ca_certificate)
  }
}
