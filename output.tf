output "vultr_kube_config" {
  value     = vultr_kubernetes.k8.kube_config
  sensitive = true
}
