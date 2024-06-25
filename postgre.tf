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

resource "kubernetes_secret" "postgre_secret" {
  metadata {
    name      = "postgre-secret"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  data = {
    username = "postgres"
    password = var.postgre_postgres_password
  }
}
