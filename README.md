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
- **Records storage account, locked down:** public network access is off, HTTPS only, TLS 1.2 minimum, and no container can be made public.
- **Private endpoint for student records:** the records storage account gets a private address inside the records spoke, plus a private DNS zone linked to the hub and records VNets so its name resolves to that address. Configuration is verified in the portal; resolution from inside a VNet hasn't been tested yet (needs a test VM).
- **Members-only videos storage:** a second storage account outside the VNets with a private container. Members will reach videos with short-lived SAS tokens issued by the app, not by network location, because they watch from home. It deploys and destroys cleanly; the SAS path itself isn't tested because the app is out of scope.
- **Pipeline identity for CI/CD:** an identity in Entra ID that GitHub Actions will log in as, using short-lived OIDC tokens instead of a stored password, with access to one resource group only. It lives in `bootstrap/` along with the resource group itself. Applied and its role checked; no workflow uses it yet.

## Roadmap (planned, not built yet)
- **CI/CD workflows (GitHub Actions):** a pull request workflow that checks and plans every change, then manual apply and destroy workflows from main. The identity they log in with is built (see Pipeline identity); the workflows are next.
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

The module takes a `private_endpoint_network_policies` value (default `Disabled`). The root sets it to `Enabled` for the records VNet only, so the records NSG applies to private endpoint traffic.

### Peering
`peerings.tf` connects the hub and the records spoke with one `azurerm_virtual_network_peering` per direction: hub → records and records → hub. Azure marks a peering Connected only when both sides exist. With one side, nothing flows.

Peering is not transitive. A studio peered to the hub couldn't reach records through it, which is why the hub will get a VPN gateway and firewall instead. Gateway transit and forwarded traffic are off until those are built.

Each peering references the module's `vnet_name` and `vnet_id` outputs, and the resource group by reference (`data.azurerm_resource_group.lab.name`), not as a typed-out string. A string gives the same name but tells Terraform nothing about what must exist first.

Terraform builds in waves, not top to bottom. Everything with nothing to wait for starts at the same time, and each reference makes a resource wait for the one it points at. The order comes from references between resources, not from where anything sits in a file.

Both peerings also have `depends_on = [module.vnets]`, so they wait until every VNet and subnet in the module is finished. Without it, Terraform created a peering at the same moment as a subnet on the same VNet, and Azure rejected the peering because it locks a VNet during a subnet change. The tradeoff: the peerings wait for every subnet in both VNets, not only the one they conflict with. On a clean deploy that added about 14 seconds.

What broke:
- A plan kept repeating an error I had already fixed. The file wasn't saved. Fix: save all files before every validate and plan.
- A VNet entry missing `name` showed as "each.value is object with 3 attributes." Fix: every VNet entry needs `name`, `address_space`, and `subnets`.
- Earlier, in the first single-VNet version, two subnets got the same name, so the second silently overwrote the first. The plan showed it; I didn't read it. Fix: read every name in the plan before apply.
- The first apply with the private endpoint built 15 of 16 resources. `peer-hub-to-records` failed with a 400 (`ReferencedResourceNotProvisioned`): the records VNet was still "Updating" from its subnet. Nothing in my code connected the peering to the subnet, so Terraform ran them in parallel. Re-running apply fixed it, and `depends_on` keeps it from happening again. Confirmed on a clean deploy (Nov 9): all 16 resources built with no error, and the log shows both peerings starting only after the last subnet finished.

Cost: VNets and subnets are free. Peering bills per GB transferred, so an idle lab costs nothing.

## Security
The records subnet has one NSG, in `nsg.tf`, with two rules:

- **Priority 100, allow:** HTTPS (443) from the two studio networks, 10.2.0.0/24 and 10.3.0.0/24. Studio staff are the only ones who should reach student records.
- **Priority 4096, deny all:** a catch-all for anything the allow rule doesn't let in.

Azure checks rules from the lowest number up and stops at the first match. I need the deny because Azure's default rule at 65000 trusts anything from a peered VNet. Without my deny, the hub, a studio on any port other than 443, or any spoke I add later could reach student records.

I put the NSG at the root instead of in the network module because only the records subnet needs one. The module builds every VNet, and Azure doesn't allow NSGs on the hub's firewall and gateway subnets.

By default, NSG rules don't apply to private endpoint traffic. The records subnet has private endpoint network policies set to `Enabled`, so the NSG filters traffic to the endpoint and route tables will apply when the firewall is built.

Not verified yet:
- The rules haven't been tested with real traffic. That happens once the studio VPNs are built.

What broke:
- Autocomplete filled in `source_address_prefixes` (which takes a list) where I needed `source_address_prefix` (one value) for `"*"`. `terraform validate` caught it. Now I check whether the value is one item or a list before I accept a suggestion.

### Records storage
`storage.tf` creates the storage account that will hold sensitive student data. It lives in the main stack, separate from the remote-state storage in `bootstrap/`.

- **Public network access disabled:** the account is closed to the internet. The only way in is the private endpoint in the records spoke.
- **HTTPS only, minimum TLS 1.2:** unencrypted connections and older, weaker encryption versions are refused.
- **No public containers:** `allow_nested_items_to_be_public = false`, so nobody can make a single container public later.
- **Standard / LRS / StorageV2:** the cheapest tier that fits. `account_kind` is the default, but I wrote it out so a provider upgrade can't change it.

The name is `stjbrecords<env>scus`. Storage account names allow only lowercase letters and numbers, no hyphens, 24 characters max, and must be unique across all of Azure, so the naming convention is shortened: `scus` is South Central US.

What broke:
- I copied an example that referenced `azurerm_resource_group.rg`, but my resource group's name is `lab`. Terraform said the resource was "not declared." That meant nothing in my files had that name, not that I needed to add a resource group. Fix: when I copy a block, check that every reference points at a name that exists in my code.

Cost: an empty Standard/LRS account costs pennies per session.

### Private endpoint
`private-endpoint.tf` creates three things:

- **Private endpoint** in the records subnet. Azure gives it a network interface with a private IP, and `private_service_connection` plugs it into the storage account's blob service.
- **Private DNS zone** `privatelink.blob.core.windows.net`. The endpoint's `private_dns_zone_group` writes the storage account's name and private IP into it.
- **Two VNet links** (`for_each` over hub and records), so lookups from inside those VNets get the private IP. The studio VNets aren't linked, because real studios are on-prem and would need DNS forwarding instead.

**Why a private endpoint instead of a service endpoint?** A service endpoint only covers traffic coming from subnets inside Azure. Our traffic comes from studio staff over the VPN, so a service endpoint would not cover them. A private endpoint gives the storage account a private IP, and the private DNS zone points its name at that IP, so public access can stay fully off. Worth the small cost (about $7.30/month) to protect minors' data.

Verified:
- Portal: endpoint Approved, A record in the zone, both VNet links Completed, records subnet policy Enabled.
- From my laptop (outside Azure): the storage name resolves through the `privatelink` alias to a public IP, and a request returns 403. The public door is locked.

Not verified yet:
- Resolution to the private IP from inside a VNet. That needs a test VM, planned with the firewall build.

What broke:
- Two references guessed module outputs that don't exist (`.id` and `["records_subnet_id"]`). Fix: a module only returns what's in its `outputs.tf` (`vnet_id`, `subnet_ids`, `vnet_name`), so I check that file instead of guessing.

Cost: a private endpoint is about $0.01/hour plus $0.01/GB processed in South Central US, and the DNS zone is about $0.50/month. A lab session costs pennies.

### Videos storage
`videos-storage.tf` creates a second storage account, `stjbvideosdevscus`, for members-only lesson videos, plus a container in it called `lesson-videos`. It's separate from the records account and from the remote-state storage, and it sits outside the VNets.

- **Network access on, anonymous access off:** a storage account has two different "public" settings. `public_network_access_enabled` decides whether the account can be reached from the internet at all. `allow_nested_items_to_be_public` decides whether someone can read a file without any credential. Members watch from home, so network access stays on. Anonymous access is off, so every request needs a SAS token.
- **Private container:** `container_access_type = "private"`.
- **HTTPS only, minimum TLS 1.2, Standard / LRS / StorageV2:** same as the records account.

**Why SAS tokens instead of a private endpoint?** Since these videos need to be accessible on the internet with the SAS token, a private endpoint would fail because this would mean that only people from inside the network or VPN would be able to access it.

Verified:
- Deployed and destroyed cleanly with the rest of the stack (Nov 10, 18 resources). The log shows the container starting on the line right after the account finished, because the container references the account's ID.

Not verified yet:
- No video uploaded and no SAS token issued. Issuing tokens is the app's job, and the app is out of scope.

Cost: an empty Standard/LRS account costs pennies per session.

### Pipeline identity
`bootstrap/` creates the identity GitHub Actions will use to reach Azure, plus the resource group the main stack deploys into.

- **App registration and service principal:** the identity itself, in Entra ID. Roles are assigned to the service principal, not the app registration.
- **Two federated credentials:** trust rules that accept GitHub's token only for this repo, one for pull requests and one for the main branch. Login uses OIDC: GitHub issues a short-lived signed token, so no password or client secret is stored anywhere.
- **Two role assignments:** Contributor on `rg-networking-dev-southcentralus` only, and Storage Blob Data Contributor on the remote-state storage account.
- **Resource group moved to bootstrap:** the main stack now reads it with a data source (`data.azurerm_resource_group.lab`) instead of creating it.
- **Provider registration off in the main stack:** `resource_provider_registrations = "none"`, because an identity scoped to one resource group can't register resource providers across the subscription.

**Why resource-group scope instead of subscription?** Least privilege is the main reason here: I want to restrict the blast radius if something bad were to happen. If the pipeline had Contributor on the subscription, anything in the subscription could be wiped clean, including the state storage. With the narrower scope it can only operate in one resource group. The tradeoff is that it can't create resource groups or register resource providers, so the RG moved to bootstrap and provider registration is turned off in the main stack.

**Why does the identity live in bootstrap?** The identity and its trust rules have to be created, and its access set up, before the pipeline can operate within its parameters. It can't create its own login or permissions. The resource group lives in bootstrap too, because it's the room that has to exist before anything else. If the main stack owned the identity and I ran destroy, it would wipe everything, including the identity and the RG.

The client ID, tenant ID, and subscription ID are stored as GitHub repository secrets, never in code. They're secrets rather than plain variables because this repo is public, and secrets are masked in workflow logs.

Verified:
- Bootstrap applied 7 resources (Nov 12). The resource group shows Succeeded, and Contributor is assigned on it.
- The main stack plans 17 resources while reading the resource group through the data source.

Not verified yet:
- Nothing has logged in as the pipeline yet. The first pull request workflow run tests the federated credential and both roles.

What broke:
- Autocomplete offered `application_id` on the service principal; azuread 3.x renamed it `client_id`. I also typed the resource type with hyphens (`azuread-service-principal`) instead of underscores. Both were caught in review before running plan.
- Renaming 14 references with find-and-replace across files ran more than once and produced `data.data.`. Fix: replace `data.data.` with `data.` until no results are left, then `git grep` to check every reference.

Cost: $0. App registrations, service principals, role assignments, and an empty resource group are free.

## File layout
- `main.tf`: resource group lookup (data source); the resource group itself is created in `bootstrap/`
- `vnet.tf`: the VNet list and studio address prefixes (`locals`) and the module call
- `peerings.tf`: hub ↔ records peering, one resource per direction
- `nsg.tf`: records subnet NSG and its association
- `storage.tf`: records storage account
- `private-endpoint.tf`: records private endpoint, blob private DNS zone, and its VNet links
- `videos-storage.tf`: videos storage account and its private container
- `modules/network/`: the module (variables, VNet and subnet resources, outputs)
- `bootstrap/`: the separate stack, applied by hand and never destroyed: remote-state storage, the resource group, and the pipeline identity with its role assignments
- `outputs.tf`, `variables.tf`, `providers.tf`, `versions.tf`

Terraform merges every .tf file in a folder. File placement is for readability and doesn't change the build order.

## Outputs
After `terraform apply`, Terraform prints three outputs:
- `resource_group_id`
- `vnet_ids`: VNet IDs keyed by VNet (`records`, `hub`)
- `subnet_ids`: subnet IDs grouped by VNet

Now: outputs let me verify what Terraform built right in the terminal, without opening the Azure portal.

Later: route tables will use these IDs. The peerings and the private endpoint read the module's outputs directly.

## Deploy and destroy

Prerequisites: Terraform (from HashiCorp's website), Azure CLI, an active Azure subscription. Run `az login` once before starting.

1. **Bootstrap first (once):** `cd bootstrap`, then `terraform init` and `terraform apply`. This creates the remote-state storage, the resource group, and the pipeline identity. Bootstrap keeps local state (ignored by git) and is never destroyed. Then `cd ..` for the main stack.
2. `terraform init`: downloads the Azure provider and the module, and connects to remote state. Run once after cloning.
3. `terraform validate`: checks the configuration for syntax and internal errors. It doesn't contact Azure.
4. `terraform plan`: shows what Terraform will create, change, or destroy, without touching anything. Currently expect 17 to add: 2 VNets, 4 subnets, 2 peerings, the NSG, its subnet association, the records storage account, the private endpoint, the private DNS zone, 2 DNS VNet links, and the videos storage account and its container. The resource group isn't in the count because bootstrap creates it.
5. `terraform apply`: Terraform reads the .tf files, calls Azure's APIs through the provider, and records what it built in state. Read the plan, then type `yes` to proceed. In the portal, each VNet's Peerings page should show Connected, the records storage account's Networking page should show public network access Disabled, the private endpoint should show Approved, and the `lesson-videos` container should show access level Private.
6. `terraform destroy`: removes everything in the main stack from Azure. Run it at the end of every session. The resource group and the pipeline identity stay, because bootstrap owns them.
7. `terraform state list`: must come back empty after destroy.

No portal steps are required.

## What I'd change at scale

- **Student sign-in with MFA:** Left out because it's application-layer authentication. It belongs to the student portal, not to the infrastructure or the CI/CD pipeline. It comes in when the portal gets built.
- **Azure Firewall Premium:** The design uses Firewall Basic, which filters and logs traffic but doesn't inspect inside encrypted connections. Premium adds intrusion detection and TLS inspection at roughly $1,278/month. It comes in if an audit or contract requires inspecting encrypted traffic.
- **Multiple environments (dev, staging, prod):** Left out because a second copy doubles the infrastructure to run and maintain. It comes in once real students depend on the system and a broken change would cost the school. The network module is built to be called more than once, so the same code can deploy each environment with different variable values.