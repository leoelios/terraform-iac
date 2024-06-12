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


resource "kubernetes_secret" "postgres_secret" {
  metadata {
    name      = "postgres-secret"
    namespace = kubernetes_namespace.infraservices.metadata[0].name
  }

  data = {
    password = var.postgres_password
  }
}

resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.infraservices.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:13"

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres_secret.metadata[0].name
                key  = "password"
              }
            }
          }

          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          volume_mount {
            name       = "postgres-data"
            mount_path = "/var/lib/postgresql/data"
          }

          port {
            container_port = 5432
          }

        }

        volume {
          name = "postgres-data"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres_pvc.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_secret.postgres_secret]
}

resource "kubernetes_persistent_volume_claim" "postgres_pvc" {
  metadata {
    name      = "postgres-pvc"
    namespace = kubernetes_namespace.infraservices.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "vultr-block-storage-hdd"

    resources {
      requests = {
        storage = "100Gi"
      }
    }
  }
}

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.infraservices.metadata[0].name
  }

  spec {
    selector = {
      app = "postgres"
    }

    type = "NodePort"

    port {
      port        = 5432
      target_port = 5432
      node_port   = 30001
    }
  }
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

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.1.2"

  values = [
    <<EOF
    server:
      service:
        type: NodePort
        nodePortHttp: 30002
        nodePortHttps: 30003
    EOF
  ]

}

resource "helm_release" "mongodb" {
  name       = "mongodb"
  namespace  = kubernetes_namespace.infraservices.metadata[0].name
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "mongodb"
  version    = "15.6.6"

  values = [
    <<EOF
    architecture: replicaset
    replicaCount: 2
    externalAccess:
      enabled: true
      service:
        type: NodePort
        nodePorts: 
          - 30004
          - 30005
    EOF
  ]

}
