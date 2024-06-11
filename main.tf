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

resource "local_file" "kubeconfig" {
  content    = base64decode(vultr_kubernetes.k8.kube_config)
  filename   = "${path.module}/kubeconfig.yaml"
  depends_on = [vultr_kubernetes.k8]
}

provider "kubernetes" {
  alias       = "dynamic"
  config_path = local_file.kubeconfig.filename
}

# resource "kubernetes_namespace" "infraservices" {
#   provider = kubernetes.dynamic

#   metadata {
#     name = "infraservices"
#   }

#   depends_on = [local_file.kubeconfig]
# }

# resource "kubernetes_persistent_volume_claim" "postgres_pvc" {
#   provider = kubernetes.dynamic

#   metadata {
#     name      = "postgres-pvc"
#     namespace = kubernetes_namespace.infraservices.metadata.0.name
#   }

#   spec {
#     access_modes = ["ReadWriteOnce"]

#     resources {
#       requests = {
#         storage = "100Gi"
#       }
#     }
#     storage_class_name = "vultr-block-storage-hdd"
#   }

#   depends_on = [kubernetes_namespace.infraservices]

# }

# resource "kubernetes_deployment" "postgres" {
#   provider = kubernetes.dynamic

#   metadata {
#     name      = "postgres"
#     namespace = kubernetes_namespace.infraservices.metadata.0.name
#     labels = {
#       app = "postgres"
#     }
#   }

#   spec {
#     replicas = 1

#     selector {
#       match_labels = {
#         app = "postgres"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           app = "postgres"
#         }
#       }

#       spec {
#         container {
#           name  = "postgres"
#           image = "postgres:latest"

#           port {
#             container_port = 5432
#           }

#           volume_mount {
#             mount_path = "/var/lib/postgresql/data"
#             name       = "postgres-data"
#           }
#         }

#         volume {
#           name = "postgres-data"
#           persistent_volume_claim {
#             claim_name = kubernetes_persistent_volume_claim.postgres_pvc.metadata.0.name
#           }
#         }
#       }
#     }
#   }

#   depends_on = [kubernetes_persistent_volume_claim.postgres_pvc]

# }
