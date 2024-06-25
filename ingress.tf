
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace.infraservices.metadata[0].name

  values = [
    yamlencode({
      controller = {
        replicaCount       = "2"
        configMapNamespace = kubernetes_namespace.infraservices.metadata[0].name

        service = {
          externalTrafficPolicy = "Local"

          internal = {
            externalTrafficPolicy = "Local"
          }
        }

        config = {
          "enable-vts-status" = true
          "proxy-body-size"   = "300m"
        }

        tcp = {
          configMapNamespace = kubernetes_namespace.infraservices.metadata[0].name
        }
      }

      tcp = {
        "27017" = "infraservices/mongodb:27017"
        "5432"  = "infraservices/postgre-postgresql:5432"
      }
    })
  ]
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

  count = var.enable_letsencrypt ? 1 : 0

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

  depends_on = [vultr_kubernetes.k8]
}
