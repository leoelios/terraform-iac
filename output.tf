output "vultr_kube_config" {
  value     = base64decode(vultr_kubernetes.k8.kube_config)
  sensitive = true
}

output "vultr_kubernetes_host" {
  value = vultr_kubernetes.k8.endpoint
}
