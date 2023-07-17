
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.64.0"
    }
  }
}

provider "azurerm" {
features {
  
}
}

resource "azurerm_resource_group" "azure-terraform" {
 name     = "cmterranskubeadm1"
 location = "East US "
}


### Création du NSG
 resource "azurerm_network_security_group" "allowports" {
   name = "allowports"
   resource_group_name = azurerm_resource_group.azure-terraform.name
   location = azurerm_resource_group.azure-terraform.location
  
   security_rule {
       name = "http"
       priority = 100
       direction = "Inbound"
       access = "Allow"
       protocol = "Tcp"
       source_port_range = "*"
       destination_port_range = "80"
       source_address_prefix = "*"
       destination_address_prefix = "*"
   }

   security_rule {
       name = "https"
       priority = 200
       direction = "Inbound"
       access = "Allow"
       protocol = "Tcp"
       source_port_range = "*"
       destination_port_range = "443"
       source_address_prefix = "*"
       destination_address_prefix = "*"
   }

   security_rule {
       name = "ssh"
       priority = 300
       direction = "Inbound"
       access = "Allow"
       protocol = "Tcp"
       source_port_range = "*"
       destination_port_range = "22"
       source_address_prefix = "*"
       destination_address_prefix = "*"
   }

   security_rule {
       name = "all"
       priority = 400
       direction = "Inbound"
       access = "Allow"
       protocol = "*"
       source_port_range = "*"
       destination_port_range = "*"
       source_address_prefix = "VirtualNetwork"
       destination_address_prefix = "VirtualNetwork"
   }
}

resource "azurerm_virtual_network" "azure-terraform" {
 name                = "acctvn"
 address_space       = ["10.0.0.0/16"]
 location            = azurerm_resource_group.azure-terraform.location
 resource_group_name = azurerm_resource_group.azure-terraform.name
}

resource "azurerm_subnet" "azure-terraform" {
 name                 = "acctsub"
 resource_group_name  = azurerm_resource_group.azure-terraform.name
 virtual_network_name = azurerm_virtual_network.azure-terraform.name
 address_prefixes       = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "master" {
 count                        = var.master_count
 name                         = "accpublicIP-master${count.index}"
 location                     = azurerm_resource_group.azure-terraform.location
 resource_group_name          = azurerm_resource_group.azure-terraform.name
 allocation_method            = "Dynamic"
 depends_on = [azurerm_resource_group.azure-terraform]
}



resource "azurerm_public_ip" "worker" {
 count                        = var.worker_count 
 name                         = "accpublicIP-worker${count.index}"
 location                     = azurerm_resource_group.azure-terraform.location
 resource_group_name          = azurerm_resource_group.azure-terraform.name
 allocation_method            = "Dynamic"
  depends_on = [azurerm_resource_group.azure-terraform]
}

resource "azurerm_network_interface" "master_nic" {
 count               = var.master_count
 name                = "acctni-master${count.index}"
 location            = azurerm_resource_group.azure-terraform.location
 resource_group_name = azurerm_resource_group.azure-terraform.name

 ip_configuration {
   name                          = "testConfiguration"
   subnet_id                     = azurerm_subnet.azure-terraform.id
   private_ip_address_allocation = "Dynamic"
   public_ip_address_id          = azurerm_public_ip.master[count.index].id
 }
   depends_on = [azurerm_resource_group.azure-terraform]
}


resource "azurerm_network_interface" "worker_nic" {
 count               = var.worker_count
 name                = "acctni-worker${count.index}"
 location            = azurerm_resource_group.azure-terraform.location
 resource_group_name = azurerm_resource_group.azure-terraform.name

 ip_configuration {
   name                          = "testConfiguration"
   subnet_id                     = azurerm_subnet.azure-terraform.id
   private_ip_address_allocation = "Dynamic"
   public_ip_address_id          = azurerm_public_ip.worker[count.index].id
 }
  depends_on = [azurerm_resource_group.azure-terraform]
}



# Connect the security group to the master NIC
resource "azurerm_network_interface_security_group_association" "master_nsg_nic" {
  count                     = length(azurerm_network_interface.master_nic.*.id)
  network_interface_id      = element(azurerm_network_interface.master_nic.*.id, count.index)
  network_security_group_id = azurerm_network_security_group.allowports.id
}



# Connect the security group to the workers NICS

resource "azurerm_network_interface_security_group_association" "wk_nsg_nic" {
  count                     = length(azurerm_network_interface.worker_nic.*.id)
  network_interface_id      = element(azurerm_network_interface.worker_nic.*.id, count.index)
  network_security_group_id = azurerm_network_security_group.allowports.id
}



resource "azurerm_managed_disk" "worker" {
 count                = var.worker_count
 name                 = "datadisk_existing-worker_${count.index}"
 location             = azurerm_resource_group.azure-terraform.location
 resource_group_name  = azurerm_resource_group.azure-terraform.name
 storage_account_type = "Standard_LRS"
 create_option        = "Empty"
 disk_size_gb         = "1023"
}

resource "azurerm_managed_disk" "master" {
 count                = var.master_count
 name                 = "datadisk_existing-master_${count.index}"
 location             = azurerm_resource_group.azure-terraform.location
 resource_group_name  = azurerm_resource_group.azure-terraform.name
 storage_account_type = "Standard_LRS"
 create_option        = "Empty"
 disk_size_gb         = "1023"
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}

#resource "local_file" "ssh.private_key" {
  #filename = "./id_rsa"
 #file_permission = "0600"
  #content  = <<-EOT
    #${tls_private_key.example_ssh.private_key_pem}
  #EOT
#}


#resource "local_file" "ssh.public_key" {
  #filename = "./id_rsa.pub"
  #file_permission = "0633"
  #content  = <<-EOT
    #${tls_private_key.example_ssh.public_key_openssh}
  #EOT
#}

resource "azurerm_linux_virtual_machine" "master" {
 count                 = var.master_count
 name                  = "acctvm-master${count.index}"
 location              = azurerm_resource_group.azure-terraform.location
 resource_group_name   = azurerm_resource_group.azure-terraform.name
 network_interface_ids = azurerm_network_interface.master_nic.*.id
 size               = "Standard_D2ds_v4"
 disable_password_authentication = false


provisioner "remote-exec" {
    inline = ["sudo dnf update", "sudo dnf install python3", "sudo dnf install python3-pip", "pip3 install ansible --user", "subscription-manager repos --enable ansible-2.8-for-rhel-8-x86_64-rpms", "dnf -y install ansible"]
    

    connection {
      host        = azurerm_linux_virtual_machine.master[count.index].public_ip_address
      type        = "ssh"
      user        = "azureuser"
      private_key = tls_private_key.example_ssh.private_key_pem
       }
         }
   
  provisioner "local-exec" {
   command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u azureuser -i '${azurerm_linux_virtual_machine.master[count.index].public_ip_address},' --private-key ${tls_private_key.example_ssh.private_key_pem} -e 'pub_key=${tls_private_key.example_ssh.public_key_openssh}' /../../ansible/kube-dependencies.yaml"
                   }
 
 #provisioner "local-exec" {
    #command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u azureuser -i '${azurerm_linux_virtual_machine.my_terraform_vm.public_ip_address},' --private-key ${local_file.idrsa.filename} -e 'pub_key=${local_file.idrsapub.filename}' /../../ansible/kube-dependencies.yaml"
    
  #}            
  tags = {
   environment = "master"
          }
           }
resource "azurerm_linux_virtual_machine" "worker" {
 count                 = var.worker_count
 name                  = "acctvm-worker${count.index}"
 location              = azurerm_resource_group.azure-terraform.location
 resource_group_name   = azurerm_resource_group.azure-terraform.name
 network_interface_ids = [element(azurerm_network_interface.worker_nic.*.id, count.index)]
 size               = "Standard_D2ds_v4"
 disable_password_authentication = false

 # Uncomment this line to delete the OS disk automatically when deleting the VM
 # delete_os_disk_on_termination = true

 # Uncomment this line to delete the data disks automatically when deleting the VM
 # delete_data_disks_on_termination = true

  source_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "8_5-gen2"
    version   = "latest"
  }
 os_disk {
    name              = "accdisk-worker-${count.index}"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
    
 }

 
 admin_username = "azureuser"
 admin_password = "P@ssw0rd123456"
 

 admin_ssh_key {
     username       = "azureuser"
     public_key     =  tls_private_key.example_ssh.public_key_openssh
 }




 tags = {
   environment = "worker"
 }



                   }
