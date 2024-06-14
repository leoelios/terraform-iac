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
        argocdServerAdminPassword: ${var.argocd_admin_password}
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

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace.infraservices.metadata[0].name

  set {
    name  = "controller.replicaCount"
    value = "2"
  }

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }
}


resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = kubernetes_namespace.infraservices.metadata[0].name
  version    = "v1.14.6"

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "kubernetes_manifest" "letsencrypt_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.tls_certificate_email
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "nginx"
              }
            }
          }
        ]
      }
    }
  }
}

resource "kubernetes_ingress" "infraservices_ingress" {
  metadata {
    name      = "infraservices-ingress"
    namespace = kubernetes_namespace.infraservices.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"           = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }
  spec {
    tls {
      hosts       = ["argocd.vava.win"]
      secret_name = "infraservices-ingress-secret"
    }
    rule {
      host = "argocd.vava.win"
      http {
        path {
          path = "/"
          backend {
            service_name = helm_release.argocd.name
            service_port = "http"
          }
        }
      }
    }
  }
}
