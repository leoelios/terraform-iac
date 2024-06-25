resource "kubernetes_namespace" "infraservices" {
  metadata {
    name = "infraservices"
  }

  depends_on = [vultr_kubernetes.k8]
}

resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }

  depends_on = [vultr_kubernetes.k8]
}
