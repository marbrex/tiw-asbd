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

resource "openstack_compute_instance_v2" "vm_test" {
  name        = "une premiere instance"
  image_name  = var.image_name
  flavor_name = var.flavor_name
  # bien penser à mettre le nom de votre clé
  key_pair    = "my-ssh-key"
}
