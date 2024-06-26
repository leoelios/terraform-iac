

output "vultr_kube_config" {
  value     = vultr_kubernetes.k8.kube_config
  sensitive = true
}

output "vultr_kubernetes_host" {
  value = vultr_kubernetes.k8.endpoint
}

output "cluster_id" {
  value = vultr_kubernetes.k8.id
}

output "argocd" {
  value = helm_release.argocd.metadata
}

output "nodes" {
  value = vultr_kubernetes.k8.node_pools[0].nodes
}

