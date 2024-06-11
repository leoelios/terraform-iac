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
  content  = base64decode(vultr_kubernetes.k8.kube_config)
  filename = "${path.module}/kubeconfig.yaml"

  depends_on = [vultr_kubernetes.k8]
}

provider "kubernetes" {
  config_path = "${path.module}/kubeconfig.yaml"
}

resource "kubernetes_namespace" "infraservices" {
  metadata {
    name = "infraservices"
  }

  depends_on = [local_file.kubeconfig]
}
