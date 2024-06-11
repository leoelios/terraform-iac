provider "vultr" {
  api_key = var.vultr_api_key
}

resource "vultr_kubernetes" "k8" {
  region  = "sao"
  label   = "vke-test"
  version = "v1.30.0+1"

  provisioner "local-exec" {
    command = "echo ${self.kube_config} > kubeconfig.txt"
  }
}

resource "vultr_kubernetes_node_pools" "np" {
  cluster_id    = vultr_kubernetes.k8.id
  node_quantity = 1
  plan          = "vc2-1c-1gb-sc1"
  label         = "vke-nodepool"
}

output "vultr_kube_config" {
  value     = vultr_kubernetes.k8.kube_config
  sensitive = true
}


# provider "kubernetes" {
#   config_path = "${path.module}/kubeconfig.txt"
# }

# resource "kubernetes_namespace" "infraservices" {
#   metadata {
#     name = "infraservices"
#   }

#   depends_on = [vultr_kubernetes.k8]
# }
