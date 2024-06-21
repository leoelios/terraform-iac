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

variable "enable_letsencrypt" {
  default     = false
  description = "Defines if letsencrypted issuer must be registered"
}

variable "mongodb_root_password" {
  description = "Root password for MongoDB"
  type        = string
  sensitive   = true
}

variable "mongodb_username" {
  description = "Username for MongoDB"
  type        = string
}

variable "mongodb_password" {
  description = "Password for MongoDB"
  type        = string
  sensitive   = true
}

variable "mongodb_database" {
  description = "Database name for MongoDB"
  type        = string
}

variable "mongodb_storage_size" {
  description = "Mongodb storage size"
  type        = string
  default     = "100Gi"
}
