resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = kubernetes_namespace.apps.metadata[0].name
  create_namespace = true
  timeout          = 1700

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.1.2"

  values = [
    <<EOF
    configs:
      params:
        server.insecure: true
      secret:
        argocdServerAdminPassword: ${var.argocd_admin_password}
    server:
      service:
        type: ClusterIP

    server:
      resources: 
        limits:
          cpu: 300m
          memory: 512Mi
        requests:
          cpu: 256m
          memory: 256Mi

    controller:
      resources: 
        limits:
          cpu: 300m
          memory: 256Mi
        requests:
          cpu: 256m
          memory: 256Mi

    repoServer:
      resources: 
        limits:
          cpu: 300m
          memory: 256Mi
        requests:
          cpu: 256m
          memory: 256Mi
    EOF
  ]

}

resource "kubernetes_ingress_v1" "argocd_ingress" {

  depends_on = [helm_release.nginx_ingress, kubernetes_manifest.letsencrypt_issuer]

  metadata {
    name      = "argocd-ingress"
    namespace = kubernetes_namespace.apps.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"                     = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/whitelist-source-range" = var.allowed_ip_range_services
    }
  }
  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = [var.argocd_service_url]
      secret_name = "argocd-ingress-secret"
    }

    rule {
      host = var.argocd_service_url

      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }

  }

}
