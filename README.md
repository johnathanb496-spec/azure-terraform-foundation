# azure-terraform-foundation
Terraform on Azure: a resource group, remote state, and a hub-and-spoke network built from code for a fictional multi-site business. Deploy and destroy with no portal steps.

## Business problem

An online guitar school with two in-person studio locations needs Azure
infrastructure that protects student data, many of whose owners are minors,
while still serving public and members-only content, within a $500/month budget.

| Data | Examples | How it's protected |
|---|---|---|
| Public | School info, offerings, free samples | Public storage, no restrictions |
| Members only | Lesson videos | Private container, short-lived access tokens issued by the app |
| Sensitive | Names, contact info, lesson notes, homework | Public access off, reachable only through a private endpoint |

Studio staff reach student records over site-to-site VPN into a hub network.
Traffic passes through Azure Firewall before it reaches the records network.

Out of scope: the student portal, student sign-in, and payments.

**Cost:** The $500/month budget is the cost of running this design around
the clock. The lab deploys and destroys everything each session, so actual
spend is a few dollars per session.

This is a hypothetical scenario. No real student data is in this repo.

## Built so far
- **Remote state in Azure Storage:** Terraform's record of what exists lives in one shared, locked place instead of on one laptop. The storage account is created by its own stack in `bootstrap/`, so destroying the main stack never deletes its own state.
- **Hub and records spoke via a reusable module:** one network module, called once per VNet with `for_each`, builds the hub and the records spoke.
- **Hub-to-spoke peering:** the hub and records spoke are connected in both directions, one peering resource per side.
- **NSG on the records subnet:** lets the studios in on HTTPS and blocks everything else. It's deployed and attached to the subnet, but I haven't tested the rules with real traffic yet because the studio networks don't exist until the VPN is built.
- **Records storage account, locked down:** public network access is off, HTTPS only, TLS 1.2 minimum, and no container can be made public. It's deployed, but nothing can reach its data yet. That comes with the private endpoint.

## Roadmap (planned, not built yet)
- **Private endpoint for student records:** gives the records storage a private address inside the records spoke, plus a private DNS zone so its name resolves to that address.
- **Members-only videos protected by identity:** a private container that members reach with short-lived access tokens, not by network location, because members watch from home.
- **CI/CD pipeline (GitHub Actions with OIDC):** every change is checked and planned automatically before it's applied, with no passwords stored anywhere.
- **Monitoring:** access logs from the records storage go to Log Analytics, with a query that shows who touched student records.
- **Site-to-site VPN for the two studios:** a VPN gateway in the hub, one connection per studio.
- **Azure Firewall Basic with route tables:** studio traffic to student records is forced through one rule set and one log before it reaches the records spoke.

## Network
A reusable network module (`modules/network/`) creates one VNet plus every subnet passed to it. The root calls it once with `for_each` over a map of VNets in `locals`, so adding a VNet means adding a map entry, not another module block.

| VNet | Address space | Subnets |
|---|---|---|
| Records spoke | 10.0.0.0/24 | snet-studentrecords-endpoint (10.0.0.0/27) |
| Hub | 10.1.0.0/24 | AzureFirewallSubnet (10.1.0.0/26), AzureFirewallManagementSubnet (10.1.0.64/26), GatewaySubnet (10.1.0.128/27) |

Every VNet is a /24, and subnets are carved out of it. The hub subnets use Azure's reserved names exactly, because Azure finds the firewall and gateway subnets by name. They skip my naming convention on purpose. No gateway or firewall is deployed yet.

### Peering
`peerings.tf` connects the hub and the records spoke with one `azurerm_virtual_network_peering` per direction: hub → records and records → hub. Azure marks a peering Connected only when both sides exist. With one side, nothing flows.

Peering is not transitive. A studio peered to the hub couldn't reach records through it, which is why the hub will get a VPN gateway and firewall instead. Gateway transit and forwarded traffic are off until those are built.

Each peering references the module's `vnet_name` and `vnet_id` outputs, and the resource group by reference (`azurerm_resource_group.lab.name`), not as a typed-out string. A string gives the same name but tells Terraform nothing about what must exist first.

Terraform builds the resource group first, then the VNets, then the subnets and peerings. The order comes from references between resources, not from where anything sits in a file.

What broke:
- A plan kept repeating an error I had already fixed. The file wasn't saved. Fix: save all files before every validate and plan.
- A VNet entry missing `name` showed as "each.value is object with 3 attributes." Fix: every VNet entry needs `name`, `address_space`, and `subnets`.
- Earlier, in the first single-VNet version, two subnets got the same name, so the second silently overwrote the first. The plan showed it; I didn't read it. Fix: read every name in the plan before apply.

Cost: VNets and subnets are free. Peering bills per GB transferred, so an idle lab costs nothing.

## Security
The records subnet has one NSG, in `nsg.tf`, with two rules:

- **Priority 100, allow:** HTTPS (443) from the two studio networks, 10.2.0.0/24 and 10.3.0.0/24. Studio staff are the only ones who should reach student records.
- **Priority 4096, deny all:** a catch-all for anything the allow rule doesn't let in.

Azure checks rules from the lowest number up and stops at the first match. I need the deny because Azure's default rule at 65000 trusts anything from a peered VNet. Without my deny, the hub, a studio on any port other than 443, or any spoke I add later could reach student records.

I put the NSG at the root instead of in the network module because only the records subnet needs one. The module builds every VNet, and Azure doesn't allow NSGs on the hub's firewall and gateway subnets.

Not verified yet:
- The rules haven't been tested with real traffic. That happens once the studio VPNs are built.
- NSG rules don't filter private endpoint traffic unless the subnet's private endpoint network policies are turned on. I'll decide that when I build the private endpoint.

What broke:
- Autocomplete filled in `source_address_prefixes` (which takes a list) where I needed `source_address_prefix` (one value) for `"*"`. `terraform validate` caught it. Now I check whether the value is one item or a list before I accept a suggestion.

### Records storage
`storage.tf` creates the storage account that will hold sensitive student data. It lives in the main stack, separate from the remote-state storage in `bootstrap/`.

- **Public network access disabled:** the account is closed to the internet. The only way in will be the private endpoint in the records spoke.
- **HTTPS only, minimum TLS 1.2:** unencrypted connections and older, weaker encryption versions are refused.
- **No public containers:** `allow_nested_items_to_be_public = false`, so nobody can make a single container public later.
- **Standard / LRS / StorageV2:** the cheapest tier that fits. `account_kind` is the default, but I wrote it out so a provider upgrade can't change it.

The name is `stjbrecords<env>scus`. Storage account names allow only lowercase letters and numbers, no hyphens, 24 characters max, and must be unique across all of Azure, so the naming convention is shortened: `scus` is South Central US.

What broke:
- I copied an example that referenced `azurerm_resource_group.rg`, but my resource group's name is `lab`. Terraform said the resource was "not declared." That meant nothing in my files had that name, not that I needed to add a resource group. Fix: when I copy a block, check that every reference points at a name that exists in my code.

Cost: an empty Standard/LRS account costs pennies per session.

## File layout
- `main.tf`: resource group
- `vnet.tf`: the VNet list and studio address prefixes (`locals`) and the module call
- `peerings.tf`: hub ↔ records peering, one resource per direction
- `nsg.tf`: records subnet NSG and its association
- `storage.tf`: records storage account
- `modules/network/`: the module (variables, VNet and subnet resources, outputs)
- `bootstrap/`: the separate stack that creates the remote-state storage
- `outputs.tf`, `variables.tf`, `providers.tf`, `versions.tf`

Terraform merges every .tf file in a folder. File placement is for readability and doesn't change the build order.

## Outputs
After `terraform apply`, Terraform prints three outputs:
- `resource_group_id`
- `vnet_ids`: VNet IDs keyed by VNet (`records`, `hub`)
- `subnet_ids`: subnet IDs grouped by VNet

Now: outputs let me verify what Terraform built right in the terminal, without opening the Azure portal.

Later: private endpoints and route tables will use these IDs. The peerings read the module's outputs directly.

## Deploy and destroy

Prerequisites: Terraform (from HashiCorp's website), Azure CLI, an active Azure subscription. Run `az login` once before starting.

1. `terraform init`: downloads the Azure provider and the module, and connects to remote state. Run once after cloning.
2. `terraform validate`: checks the configuration for syntax and internal errors. It doesn't contact Azure.
3. `terraform plan`: shows what Terraform will create, change, or destroy, without touching anything. Currently expect 12 to add: the resource group, 2 VNets, 4 subnets, 2 peerings, the NSG, its subnet association, and the records storage account.
4. `terraform apply`: Terraform reads the .tf files, calls Azure's APIs through the provider, and records what it built in state. Read the plan, then type `yes` to proceed. In the portal, each VNet's Peerings page should show Connected, and the records storage account's Networking page should show public network access Disabled.
5. `terraform destroy`: removes everything in state from Azure. Run it at the end of every session.
6. `terraform state list`: must come back empty after destroy.

No portal steps are required.

## What I'd change at scale

- **Student sign-in with MFA:** Left out because it's application-layer authentication. It belongs to the student portal, not to the infrastructure or the CI/CD pipeline. It comes in when the portal gets built.
- **Azure Firewall Premium:** The design uses Firewall Basic, which filters and logs traffic but doesn't inspect inside encrypted connections. Premium adds intrusion detection and TLS inspection at roughly $1,278/month. It comes in if an audit or contract requires inspecting encrypted traffic.
- **Multiple environments (dev, staging, prod):** Left out because a second copy doubles the infrastructure to run and maintain. It comes in once real students depend on the system and a broken change would cost the school. The network module is built to be called more than once, so the same code can deploy each environment with different variable values.