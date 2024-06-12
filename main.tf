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
  alias = "dynamic"

  host = "https://${vultr_kubernetes.k8.endpoint}:6443"

  client_certificate     = base64decode(vultr_kubernetes.k8.client_certificate)
  client_key             = base64decode(vultr_kubernetes.k8.client_key)
  cluster_ca_certificate = base64decode(vultr_kubernetes.k8.cluster_ca_certificate)
}

resource "kubernetes_namespace" "infraservices" {
  provider = kubernetes.dynamic

  metadata {
    name = "infraservices"
  }

  depends_on = [vultr_kubernetes.k8]
}

resource "kubernetes_namespace" "apps" {
  provider = kubernetes.dynamic

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
    password = base64encode(var.postgres_password)
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

    port {
      port        = 5432
      target_port = 5432
    }
  }
}
