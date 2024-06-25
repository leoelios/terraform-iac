provider "vultr" {
  api_key = var.vultr_api_key
}


resource "vultr_kubernetes" "k8" {
  region  = "sao"
  label   = "vke-test"
  version = "v1.30.0+1"

  node_pools {
    node_quantity = 2
    plan          = "vc2-2c-4gb-sc1"
    label         = "vke-nodepool"
    auto_scaler   = true
    min_nodes     = 1
    max_nodes     = 3
  }
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

  depends_on = [vultr_kubernetes.k8]
}

resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }

  depends_on = [vultr_kubernetes.k8]
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

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1"

  values = [
    <<EOF
      resources:
        cpu: 200m
        memory: 300Mi
    EOF
  ]
}

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

resource "kubernetes_ingress_v1" "apps_ingress" {

  depends_on = [helm_release.nginx_ingress, kubernetes_manifest.letsencrypt_issuer]

  metadata {
    name      = "apps-ingress"
    namespace = kubernetes_namespace.apps.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }
  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = ["argocd.vava.win"]
      secret_name = "apps-ingress-secret"
    }

    rule {
      host = "argocd.vava.win"

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

resource "helm_release" "mongodb" {
  name       = "mongodb"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "mongodb"
  namespace  = kubernetes_namespace.infraservices.metadata[0].name
  version    = "15.6.9"

  values = [
    yamlencode({
      resourcesPreset = "micro"

      arbiter = {
        resourcesPreset = "micro"
      }

      hidden = {
        resourcesPreset = "micro"
      }

      auth = {
        enabled      = true
        rootPassword = var.mongodb_root_password
        username     = var.mongodb_username
        password     = var.mongodb_password
        database     = var.mongodb_database
      }
      persistence = {
        size         = var.mongodb_storage_size
        storageClass = "vultr-block-storage-hdd"
      }
    })
  ]
}

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

resource "helm_release" "postgre" {
  name       = "postgre"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  namespace  = kubernetes_namespace.infraservices.metadata[0].name
  version    = "15.5.9"

  values = [
    yamlencode({

      auth = {
        postgresPassword = var.postgre_postgres_password
      }

      primary = {
        resourcesPreset = "micro"
        persistence = {
          size         = var.postgres_storage_size
          storageClass = "vultr-block-storage-hdd"
        }
      }

    })
  ]
}

resource "kubernetes_config_map" "tcp_services" {
  depends_on = [helm_release.mongodb, kubernetes_persistent_volume_claim.registry_pvc]

  metadata {
    name      = "tcp-services"
    namespace = kubernetes_namespace.infraservices.metadata[0].name
  }

  data = {
    "27017" = "infraservices/mongodb:27017"
    "5432"  = "infraservices/postgre-postgresql:5432"
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
    namespace = kubernetes_namespace.infraservices.metadata[0].name
  }

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "registry.vava.win" = {
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
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/rewrite-target" : "/"
    }
  }
  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = ["registry.vava.win"]
      secret_name = "registry-ingress-secret"
    }

    rule {
      host = "registry.vava.win"

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

