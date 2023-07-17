#!/bin/bash
terraform output -raw Cle_privee > id_rsa
sudo chmod 400 id_rsa
sudo echo -e "[masters]\n\nmaster ansible_host=$(terraform output -raw IP_manager) ansible_user=azureuser\nmaster ansible_ssh_private_key_file=id_rsa\n\n[workers]\n\nworker0 ansible_host=$(terraform output -raw IP_worker_0) ansible_user=azureuser\nworker0 ansible_ssh_private_key_file=id_rsa\n\nworker1 ansible_host=$(terraform output -raw IP_worker_1) ansible_user=azureuser\nworker1 ansible_ssh_private_key_file=id_rsa" > ../../ansible/inventory
