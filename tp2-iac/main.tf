resource "openstack_networking_network_v2" "network-asbd-edgerunner" {
  name           = "network-asbd-edgerunner"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "asbd-subnet-front" {
  network_id      = "${openstack_networking_network_v2.network-asbd-edgerunner.id}"
  cidr            = "10.245.199.0/24"
  dns_nameservers = ["10.10.10.10", "10.10.10.11"]
  allocation_pool {
    start = "10.245.199.100"
    end   = "10.245.199.150"
  }
}

# Creer une compute instance de test:
# resource "openstack_compute_instance_v2" "vm_test" {
#   name        = "une premiere instance"
#   image_name  = var.image_name
#   flavor_name = var.flavor_name
#   # bien penser à mettre le nom de votre clé
#   key_pair    = "my-ssh-key"
# }

# Creer un router pour pouvoir se connecter a l'instance
resource "openstack_networking_router_v2" "routeur-asbd" {
  name                = "routeur-asbd"
  admin_state_up      = true
  external_network_id = "${data.openstack_networking_network_v2.external-network.id}"
}

resource "openstack_networking_router_interface_v2" "routeur-interface-asbd" {
  router_id = "${openstack_networking_router_v2.routeur-asbd.id}"
  subnet_id = "${openstack_networking_subnet_v2.asbd-subnet-front.id}"
}

resource "openstack_networking_subnet_v2" "asbd-subnet-worker" {
  network_id      = "${openstack_networking_network_v2.network-asbd-edgerunner.id}"
  cidr            = "10.245.189.0/24"
  dns_nameservers = ["10.10.10.10", "10.10.10.11"]
}

resource "openstack_networking_subnet_v2" "asbd-subnet-db" {
  network_id      = "${openstack_networking_network_v2.network-asbd-edgerunner.id}"
  cidr            = "10.245.185.0/24"
  dns_nameservers = ["10.10.10.10", "10.10.10.11"]
}

resource "openstack_compute_instance_v2" "vm-front" {
  name            = "front"
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  # bien penser à mettre le nom de votre clé
  key_pair        = "my-ssh-key"
  security_groups = ["default"]

  metadata = {
    machine_type = "front"
  }

  network {
    name = "asbd-subnet-front"
  }
}

resource "openstack_compute_floatingip_associate_v2" "fip-front" {
  floating_ip = "${data.openstack_networking_floatingip_v2.floating-ip.address}"
  instance_id = "${openstack_compute_instance_v2.vm-front.id}"
}

resource "openstack_compute_instance_v2" "vm-worker" {
  name            = "worker"
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  # bien penser à mettre le nom de votre clé
  key_pair        = "my-ssh-key"
  security_groups = ["default"]

  metadata = {
    machine_type = "worker"
  }

  network {
    name = "asbd-subnet-worker"
  }
}

resource "openstack_compute_instance_v2" "vm-db" {
  name            = "db"
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  # bien penser à mettre le nom de votre clé
  key_pair        = "my-ssh-key"
  security_groups = ["default"]

  metadata = {
    machine_type = "db"
  }

  network {
    name = "asbd-subnet-db"
  }
}
