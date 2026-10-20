# azure-terraform-foundation
Terraform on Azure: a resource group, network, and security built from code. Deploy and destroy with no portal steps.


# Network: VNet and subnets 
One VNet (10.0.0.0/24) with two /26 subnets split by job: app (.0–.63) and management (.64–.127), leaving half the space free. 
Terraform builds the RG, then the VNet, then both subnets in parallel. The order comes from references, not anything I wrote. 

What broke: both subnets got the same name, so the second silently overwrote the first. The plan showed it; I didn’t read it. 

Fix: unique names per subnet, and read every name in the plan before apply. 

Cost: VNets and subnets are free.

# Security
Each subnet has its own NSG (nsg-app-…, nsg-management-…) with zero custom rules. Azure’s default rules apply: traffic from inside the VNet is allowed, Azure Load Balancer health probes are allowed, and everything else inbound is denied (DenyAllInBound, priority 65500). Nothing runs in these subnets yet, so there is nothing to justify opening. Any future allow rule gets its own decision-log entry.

One NSG per subnet, not one shared: a rule opening port 443 for app would otherwise open it on management too.

# File layout

main.tf resource group · vnet.tf virtual network · snet.tf subnets · nsg.tf NSGs + subnet associations · variables.tf · providers.tf · versions.tf. Terraform merges every .tf file in the folder; file placement is for readability and doesn’t change the build order.

Cost: NSGs and associations are free.