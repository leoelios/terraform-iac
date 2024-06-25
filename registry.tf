
resource "kubernetes_persistent_volume_claim" "registry_pvc" {
  metadata {
    name = "registry-pvc"
    labels = {
      app = "docker-registry"
    }
    namespace = kubernetes_namespace.infraservices.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "40Gi"
      }
    }
  }
}


resource "kubernetes_service" "registry_service" {
  metadata {
    name = "registry"
    labels = {
      app = "docker-registry"
    }
    namespace = kubernetes_namespace.infraservices.metadata[0].name
  }

  spec {
    selector = {
      app = "docker-registry"
    }

    port {
      protocol    = "TCP"
      port        = 5000
      target_port = 5000
    }

    type = "ClusterIP"
  }
}


resource "kubernetes_deployment" "docker_registry" {
  depends_on = [vultr_kubernetes.k8]

  metadata {
    name = "docker-registry"
    labels = {
      app = "docker-registry"
    }
    namespace = kubernetes_namespace.infraservices.metadata[0].name
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "docker-registry"
      }
    }

    template {
      metadata {
        labels = {
          app = "docker-registry"
        }
      }

      spec {
        volume {
          name = "auth-volume"
          empty_dir {}
        }

        volume {
          name = "registry-storage"
          persistent_volume_claim {
            claim_name = "registry-pvc"
          }
        }

        init_container {
          name  = "init-auth"
          image = "alpine:3.13"

          command = [
            "sh",
            "-c",
            "apk add --no-cache apache2-utils && htpasswd -Bcb /auth/htpasswd ${var.registry_user} ${var.registry_password}"
          ]

          volume_mount {
            name       = "auth-volume"
            mount_path = "/auth"
          }
        }

        container {
          name  = "registry"
          image = "registry:2"

          port {
            container_port = 5000
          }

          volume_mount {
            name       = "auth-volume"
            mount_path = "/auth"
          }

          volume_mount {
            name       = "registry-storage"
            mount_path = "/var/lib/registry"
          }

          env {
            name  = "REGISTRY_AUTH"
            value = "htpasswd"
          }

          env {
            name  = "REGISTRY_AUTH_HTPASSWD_REALM"
            value = "Registry"
          }

          env {
            name  = "REGISTRY_AUTH_HTPASSWD_PATH"
            value = "/auth/htpasswd"
          }
        }
      }
    }
  }
}

resource "kubernetes_secret" "docker_registry_secret" {
  metadata {
    name      = "registry-secret"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "registry.${service_domain}" = {
          username = "${var.registry_user}"
          password = "${var.registry_password}"
          auth     = base64encode("${var.registry_user}:${var.registry_password}")
        }
      }
    })
  }

  type = "kubernetes.io/dockerconfigjson"
}

resource "kubernetes_ingress_v1" "registry_ingress" {

  depends_on = [helm_release.nginx_ingress, kubernetes_manifest.letsencrypt_issuer]

  metadata {
    name      = "registry-ingress"
    namespace = kubernetes_namespace.infraservices.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"             = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    }
  }
  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = ["registry.${var.service_domain}"]
      secret_name = "registry-ingress-secret"
    }

    rule {
      host = "registry.${var.service_domain}"

      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "registry"
              port {
                number = 5000
              }
            }
          }
        }
      }
    }

  }

}
