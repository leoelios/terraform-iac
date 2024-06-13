provider "vultr" {
  api_key = var.vultr_api_key
}


resource "vultr_kubernetes" "k8" {
  region  = "sao"
  label   = "vke-test"
  version = "v1.30.0+1"

  node_pools {
    node_quantity = 4
    plan          = "vc2-1c-1gb-sc1"
    label         = "vke-nodepool"
    auto_scaler   = true
    min_nodes     = 2
    max_nodes     = 6
  }
}

resource "null_resource" "wait_for_time" {
  triggers = {
    start_time = timestamp()
  }

  provisioner "local-exec" {
    command = "sleep 10"
  }

  depends_on = [
    vultr_kubernetes.k8
  ]
}

provider "kubernetes" {
  host = "https://${vultr_kubernetes.k8.endpoint}:6443"

  client_certificate     = base64decode(vultr_kubernetes.k8.client_certificate)
  client_key             = base64decode(vultr_kubernetes.k8.client_key)
  cluster_ca_certificate = base64decode(vultr_kubernetes.k8.cluster_ca_certificate)
}

resource "kubernetes_namespace" "infraservices" {
  metadata {
    name = "infraservices"
  }

  depends_on = [vultr_kubernetes.k8, null_resource.wait_for_time]
}

resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }

  depends_on = [vultr_kubernetes.k8, null_resource.wait_for_time]
}

provider "helm" {
  kubernetes {
    host = "https://${vultr_kubernetes.k8.endpoint}:6443"

    client_certificate     = base64decode(vultr_kubernetes.k8.client_certificate)
    client_key             = base64decode(vultr_kubernetes.k8.client_key)
    cluster_ca_certificate = base64decode(vultr_kubernetes.k8.cluster_ca_certificate)
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = kubernetes_namespace.apps.metadata[0].name
  create_namespace = true
  timeout          = 900

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.1.2"

  values = [
    <<EOF
    configs:
      secret:
        argocdServerAdminPassword: 1234
    server:
      service:
        type: LoadBalancer
    EOF
  ]

}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1"
}

# resource "helm_release" "mongodb" {
#   name       = "mongodb"
#   namespace  = kubernetes_namespace.infraservices.metadata[0].name
#   repository = "https://charts.bitnami.com/bitnami"
#   chart      = "mongodb"
#   version    = "15.6.5"
#   timeout    = 900

#   values = [
#     <<EOF
#     persistence:
#       size: 200Gi
#       storageClass: vultr-block-storage-hdd

#     diagnosticMode:
#       enabled: true

#     resourcesPreset: nano
#     arbiter:
#       resourcesPreset: nano

#     architecture: standalone
#     externalAccess:
#       enabled: true
#       service:
#         type: NodePort
#         nodePorts: 
#           - 30004
#     EOF
#   ]

# }
