
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
