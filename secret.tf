resource "kubernetes_secret" "api_commons_secret" {
  metadata {
    name      = "api-commons-secret"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  data = {
    secret           = var.api_secret_key
    sendgrid_api_key = var.sendgrid_api_key
  }
}
