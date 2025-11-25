output "vm_ips" {
  description = "All VM IP addresses"
  value = {
    k3s-master = "10.12.14.15",
    k3s-node1  = "10.12.14.16",
    gitlab     = "10.12.14.17",
    gitlab-runner = "10.12.14.18",
    postgres-prod = "10.12.14.19",
    
  }
}