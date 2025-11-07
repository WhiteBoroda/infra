output "vm_ips" {
  description = "All VM IP addresses"
  value = {
    k3s-master = "192.168.0.20",
    k3s-node1  = "192.168.0.21",
    gitlab     = "192.168.0.22",
    monitoring = "192.168.0.23",
    redis      = "192.168.0.24",
    postgres   = "192.168.0.25"
  }
}