terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "3.0.2-rc05"
    }
  }
}

provider "proxmox" {
  pm_api_url = var.pm_api_url
  pm_api_token_id = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure = true
}

resource "proxmox_vm_qemu" "k3s_master" {
  name         = "k3s-master"
  target_node  = var.target_node
  clone        = var.template_name
  full_clone   = true

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }

  memory  = 8192
  scsihw  = "virtio-scsi-single"
  os_type = "cloud-init"

  disks {
    scsi {
      scsi0 {
        disk {
          backup     = true
          cache      = "none"
          discard    = true
          emulatessd = true
          iothread   = true
          size       = 32
          storage    = var.storage
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  
# Cloud-Init configuration
#  cicustom   = "vendor=local:snippets/qemu-guest-agent.yml" # /var/lib/vz/snippets/qemu-guest-agent.yml
  ciupgrade  = true
  nameserver = "192.168.0.1"
  ipconfig0  = "ip=192.168.0.20/24,gw=192.168.0.1,ip6=dhcp"
  skip_ipv6  = true
  ciuser     = "root"
  cipassword = "Enter123!"
  sshkeys    = file(var.ssh_pubkey_path)

#  cicustom   = "vendor=local:snippets/qemu-guest-agent.yml"
#  ciuser     = "ubuntu"
#  cipassword = "Z_Xcvbn-12"
#  sshkeys    = file(var.ssh_pubkey_path)
#  ipconfig0  = "ip=192.168.0.20/24,gw=192.168.0.1"
#  bootdisk   = "scsi0"
#  boot       = "cdn"

  agent = 1
}
resource "proxmox_vm_qemu" "k3s_node1" {
  name         = "k3s-node1"
  target_node  = var.target_node
  clone        = var.template_name
  full_clone   = true

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }

  memory  = 8192
  scsihw  = "virtio-scsi-single"
  os_type = "cloud-init"

  disks {
    scsi {
      scsi0 {
        disk {
          backup     = true
          cache      = "none"
          discard    = true
          emulatessd = true
          iothread   = true
          size       = 32
          storage    = var.storage
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

#  cicustom   = "vendor=local:snippets/qemu-guest-agent.yml"
  ciuser     = "ubuntu"
  cipassword = "Z_Xcvbn-12"
  sshkeys    = file(var.ssh_pubkey_path)
  ipconfig0  = "ip=192.168.0.21/24,gw=192.168.0.1"
  bootdisk   = "scsi0"
  boot       = "cdn"

  agent = 1
}


resource "proxmox_vm_qemu" "gitlab" {
  name         = "gitlab"
  target_node  = var.target_node
  clone        = var.template_name
  full_clone   = true

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }

  memory  = 8192
  scsihw  = "virtio-scsi-single"
  os_type = "cloud-init"

  disks {
    scsi {
      scsi0 {
        disk {
          backup     = true
          cache      = "none"
          discard    = true
          emulatessd = true
          iothread   = true
          size       = 64
          storage    = var.storage
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

#  cicustom   = "vendor=local:snippets/qemu-guest-agent.yml"
  ciuser     = "ubuntu"
  cipassword = "Z_Xcvbn-12"
  sshkeys    = file(var.ssh_pubkey_path)
  ipconfig0  = "ip=192.168.0.22/24,gw=192.168.0.1"
  bootdisk   = "scsi0"
  boot       = "cdn"

  agent = 1
}

resource "proxmox_vm_qemu" "monitoring" {
  name         = "monitoring"
  target_node  = var.target_node
  clone        = var.template_name
  full_clone   = true

  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
  }

  memory  = 4096
  scsihw  = "virtio-scsi-single"
  os_type = "cloud-init"

  disks {
    scsi {
      scsi0 {
        disk {
          backup     = true
          cache      = "none"
          discard    = true
          emulatessd = true
          iothread   = true
          size       = 32
          storage    = var.storage
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

#  cicustom   = "vendor=local:snippets/qemu-guest-agent.yml"
  ciuser     = "ubuntu"
  cipassword = "Z_Xcvbn-12"
  sshkeys    = file(var.ssh_pubkey_path)
  ipconfig0  = "ip=192.168.0.23/24,gw=192.168.0.1"
  bootdisk   = "scsi0"
  boot       = "cdn"

  agent = 1
}
resource "proxmox_lxc" "redis" {
  hostname     = "redis-lxc"
  target_node  = var.target_node
  ostemplate   = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  password     = "Z_Xcvbn-12"
  cores        = 2
  memory       = 1024
  swap         = 512
  start        = true
  unprivileged = true

  rootfs {
    storage = var.storage
    size    = "8G"
  }

  features {
    nesting = true
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "192.168.0.24/24"
    gw     = "192.168.0.1"
  }
}

resource "proxmox_vm_qemu" "postgres" {
  name         = "postgres"
  target_node  = var.target_node
  clone        = var.template_name
  full_clone   = true

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }

  memory  = 8192
  scsihw  = "virtio-scsi-single"
  os_type = "cloud-init"

  disks {
    scsi {
      scsi0 {
        disk {
          backup     = true
          cache      = "none"
          discard    = true
          emulatessd = true
          iothread   = true
          size       = 32
          storage    = var.storage
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

#  cicustom   = "vendor=local:snippets/qemu-guest-agent.yml"
  ciuser     = "ubuntu"
  cipassword = "Z_Xcvbn-12"
  sshkeys    = file(var.ssh_pubkey_path)
  ipconfig0  = "ip=192.168.0.25/24,gw=192.168.0.1"
  bootdisk   = "scsi0"
  boot       = "cdn"

  agent = 1
}