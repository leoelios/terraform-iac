provider "vultr" {
  api_key = var.vultr_api_key
}

resource "vultr_kubernetes" "k8" {
  region  = "sao"
  label   = "vke-test"
  version = "v1.30.0+1"

  node_pools {
    node_quantity = 1
    plan          = "vc2-1c-1gb-sc1"
    label         = "vke-nodepool"
    auto_scaler   = true
    min_nodes     = 1
    max_nodes     = 2
  }
}

resource "local_file" "kubeconfig" {
  filename   = "${path.module}/kubeconfig.yaml"
  content    = vultr_kubernetes.k8.kube_config
  depends_on = [vultr_kubernetes.k8]
}

provider "kubernetes" {
  alias       = "dynamic"
  config_path = local_file.kubeconfig.filename
}

resource "kubernetes_namespace" "infraservices" {
  provider = kubernetes.dynamic

  metadata {
    name = "infraservices"
  }

  depends_on = [local_file.kubeconfig]
}
