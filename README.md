# azure-terraform-foundation
Terraform on Azure: a resource group, network, and security built from code. Deploy and destroy with no portal steps.

## Business problem
An online guitar school needs infrastructure that protects student data while having public content, and cannot exceed a budget of $20/month.

- **Public:** school info, lesson offerings, and free sample videos anyone can watch.
- **Members only:** lesson videos students can watch after they sign up.
- **Sensitive:** student names, contact info, email, lesson notes, and assigned homework. Many students are minors.

This is a hypothetical scenario. No real student data is in this repo.

## Roadmap (planned, not built yet)
- **Remote state in Azure Storage:** Terraform's record of what exists lives in one shared, locked place instead of on one laptop, so the pipeline and I work from the same copy.
- **Hub-and-spoke network via a reusable module:** keeps the student records system separate from everything else, with a hub for shared services.
- **Private storage for student records:** public internet access is turned off, and the storage is reachable only through a private endpoint inside the network.
- **CI/CD pipeline (GitHub Actions with OIDC):** every change is checked and planned automatically before it's applied, with no passwords stored anywhere.

## Network: VNet and subnets
One VNet (10.0.0.0/24) with two /26 subnets split by job: app (.0–.63) and management (.64–.127), leaving half the space free.
Terraform builds the RG, then the VNet, then both subnets in parallel. The order comes from references, not anything I wrote.

What broke: both subnets got the same name, so the second silently overwrote the first. The plan showed it; I didn't read it.

Fix: unique names per subnet, and read every name in the plan before apply.

Cost: VNets and subnets are free.

## Security
Each subnet has its own NSG (nsg-app-…, nsg-management-…) with zero custom rules. Azure's default rules apply: traffic from inside the VNet is allowed, Azure Load Balancer health probes are allowed, and everything else inbound is denied (DenyAllInBound, priority 65500). Nothing runs in these subnets yet, so there is nothing to justify opening. Any future allow rule gets its own decision-log entry.

One NSG per subnet, not one shared: a rule opening port 443 for app would otherwise open it on management too.

Cost: NSGs and associations are free.

## File layout
main.tf resource group · vnet.tf virtual network · snet.tf subnets · nsg.tf NSGs + subnet associations · outputs.tf outputs · variables.tf · providers.tf · versions.tf. Terraform merges every .tf file in the folder; file placement is for readability and doesn't change the build order.

## Outputs
After `terraform apply`, Terraform prints six outputs:
- `resource_group_id`
- `vnet_id`
- `subnet_app_id`
- `subnet_management_id`
- `nsg_app_id`
- `nsg_management_id`

Now: outputs let me verify what Terraform built right in the terminal, without opening the Azure portal.

Later: outputs let other Terraform code access the VNet ID it needs once the network is inside a module.

## Deploy and destroy

Prerequisites: Terraform (from HashiCorp's website), Azure CLI, an active Azure subscription. Run `az login` once before starting.

1. `terraform init` — Downloads the Azure provider and sets up the folder. Run once after cloning.
2. `terraform validate` — Checks the configuration for syntax and internal errors. It doesn't contact Azure.
3. `terraform plan` — Shows what Terraform will create, change, or destroy, without touching anything.
4. `terraform apply` — Terraform reads the .tf files, calls Azure's APIs through the provider, and records what it built in state. Read the plan, then type `yes` to proceed.
5. `terraform destroy` — Removes everything in state from Azure. Run it at the end of every session.

No portal steps are required.

## What I'd change at scale

- **Student sign-in with MFA:** Left out because it's application-layer authentication. It belongs to the student portal, not to the infrastructure or the CI/CD pipeline. It comes in when the portal gets built.
- **Azure Firewall:** Left out on cost (about $912/month against a $20 budget). It comes in if the school grows enough that a contract or audit requires central inspection and logging of network traffic.
- **Multiple environments (dev, staging, prod):** Left out because a second copy doubles the infrastructure to run and maintain. It comes in once real students depend on the system and a broken change would cost the school. The network module will be built to be called more than once, so the same code can deploy each environment with different variable values.