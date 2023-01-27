# Pour get external_network_id de Routeur 
data "openstack_networking_network_v2" "external-network" {

  # c'est un attribut (nom dans OpenStack),
  # tandis que le nom ci-dessus est un nom dans le code Terraform,
  # donc cet attribut peut etre commente
  # name = "external-network"

  tags = ["external"]

}

data "openstack_networking_floatingip_v2" "floating-ip" {
  tags = ["access_ip"]
}