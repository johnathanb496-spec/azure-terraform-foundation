# azure-terraform-foundation
Terraform on Azure: a resource group, network, and security built from code. Deploy and destroy with no portal steps.


## Network: VNet and subnets 
One VNet (10.0.0.0/24) with two /26 subnets split by job: app (.0–.63) and management (.64–.127), leaving half the space free. 
Terraform builds the RG, then the VNet, then both subnets in parallel. The order comes from references, not anything I wrote. 

What broke: both subnets got the same name, so the second silently overwrote the first. The plan showed it; I didn’t read it. 

Fix: unique names per subnet, and read every name in the plan before apply. 

Cost: VNets and subnets are free.