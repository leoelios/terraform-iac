provider "kubernetes" {
  config_path = "${path.module}/kubeconfig.txt"
}

resource "kubernetes_namespace" "infraservices" {
  metadata {
    name = "infraservices"
  }

  depends_on = [vultr.vultr_kubernetes.k8]
}
