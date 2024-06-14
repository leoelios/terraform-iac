# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


variable "vultr_api_key" {
  description = "VULTR Api key for K8S cluster creation"
  sensitive   = true
  nullable    = false
}

variable "postgres_password" {
  description = "Default postgres user password for setup"
  nullable    = false
  sensitive   = true
}

variable "argocd_admin_password" {
  description = "ArgoCD admin password encrypted in Bcrypt algorithm (Default: 1234)"
  nullable    = false
  sensitive   = false
  default     = "$2a$12$X02/Jug5WHV.1vpWqqwdmu.jOEcoMKB8cUaDQo6U5dnf./w3DVAqK"
}

variable "tls_certificate_email" {
  description = "E-mail for generating TLS certificates in Let's encrypt"
  nullable    = false
}
