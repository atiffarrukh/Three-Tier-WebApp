# Three-Tier-WebApp
A three tier web application, deployed using Terraform, Ansible and Packer

# Terraform!
Terraform create the infrastructure for the applicaiton. The infrastructure includes
  - Resource Group
  - Virtual Network with two subnets for Application Gateway, one for front-end VMs and one for business logic VMs and one subnet for bastion VM 
  - A bastion Linux Virtual Machine to be able to connect to any of the VM, if needs to be
  - A Windows Virtual Machine Scale Set (VMSS) for application front-end. The Virtual Machines are based on custom Windows Server 2016 image, which is present in Shared Image Gallery, created by using Packer and Ansible
  - A Windows Virtual Machine Scale Set (VMSS) for application business logic. The Virtual Machines are based on custom Windows Server 2016 image, which is present in Shared Image Gallery, created by using Packer and Ansible
  - A MSSQL Server and MSSQL database
  - A Shared Image Gallery
  - A Storage Account and a container and create a SAS token to access blob

# Ansible
Ansible is responsible for uploading and configuring the published application code

# Packer
Packer takes the already build custom image, containing only IIS, and do the following tasks
 - User Powershell to enable WinRM
 - Use Ansible as Provisioner to upload and configure the published code to VM.
 - User Sysrep to generalize the custom image to be used by Terraform to create/update Windows VMSS

# Azure DevOps
Azure DevOps is used for CI/CD for the infrastructure and applicaition
 - A build pipeline is used to build the application whenever code is commited to master branch
 - If build is a scuccess, a Release pipeline is triggered. The Release pipeline runs the packer script. The VM is deployed for QA.
 - Once QA passes the build and configuration, a manual approval is required for the OS image to be updated for already running VMSS. The VMSS are configured to roll out upgrades in incremental manner.