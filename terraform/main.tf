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
    ide {
      ide1 {
        cloudinit {
            storage = var.storage
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }
 
  ciupgrade  = true
  ipconfig0  = "ip=10.12.14.15/24,gw=10.12.14.254"
  skip_ipv6  = true
  ciuser     = var.ci_username
  cipassword = var.ci_password
  nameserver = var.ci_nameserver
  sshkeys    = file(var.ssh_pubkey_path)
  bootdisk   = "scsi0"
  boot       = "cdn"
  agent      = 1
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
    ide {
      ide1 {
        cloudinit {
            storage = var.storage
        }
      }
    }
  }
  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }
  ciuser     = var.ci_username
  cipassword = var.ci_password
  nameserver = var.ci_nameserver
  sshkeys    = file(var.ssh_pubkey_path)
  ipconfig0  = "ip=10.12.14.16/24,gw=10.12.14.254"
  bootdisk   = "scsi0"
  boot       = "cdn"
  agent      = 1
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
    ide {
      ide1 {
        cloudinit {
            storage = var.storage
        }
      }
    }
  }
  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
    }
  ciuser     = var.ci_username
  cipassword = var.ci_password
  nameserver = var.ci_nameserver
  sshkeys    = file(var.ssh_pubkey_path)
  ipconfig0  = "ip=10.12.14.17/24,gw=10.12.14.254"
  bootdisk   = "scsi0"
  boot       = "cdn"
  agent      = 1
}

resource "proxmox_vm_qemu" "gitlab_runner" {
  name         = "gitlab-runner"
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
    ide {
      ide1 {
        cloudinit {
            storage = var.storage
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }
  
  ciuser     = var.ci_username
  cipassword = var.ci_password
  nameserver = var.ci_nameserver
  sshkeys    = file(var.ssh_pubkey_path)
  ipconfig0  = "ip=10.12.14.18/24,gw=10.12.14.254"
  bootdisk   = "scsi0"
  boot       = "cdn"
  agent      = 1
}

resource "proxmox_vm_qemu" "postgres_prod" {
  name         = "postgres-prod"
  target_node  = var.target_node
  clone        = var.template_name
  full_clone   = true

  cpu {
    cores   = 8
    sockets = 1
    type    = "host"
  }

  memory  = 16384
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
          size       = 500  # 500GB for production database (currently 200GB + growth)
          storage    = var.storage
        }
      }
    }
    ide {
      ide1 {
        cloudinit {
            storage = var.storage
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }
  
  ciuser     = var.ci_username
  cipassword = var.ci_password
  nameserver = var.ci_nameserver
  sshkeys    = file(var.ssh_pubkey_path)
  ipconfig0  = "ip=10.12.14.19/24,gw=10.12.14.254"
  bootdisk   = "scsi0"
  boot       = "cdn"
  agent      = 1
}
