# AWS multi-region network platform

Two-region hub-and-spoke build on Transit Gateway with centralized Palo Alto
VM-Series inspection behind Gateway Load Balancers, and a separate internet
ingress landing zone fronted by a Network Load Balancer.

Per region: 1 Transit Gateway, 6 spoke VPCs, 1 inspection VPC, 1 ingress VPC,
1 log archive bucket. The two regions are joined by a TGW peering attachment.

---

## Layout

```
bootstrap/                        S3 state buckets + DynamoDB lock tables
docs/iam.md                       IAM roles and permissions reference
docs/diagrams/                    editable .drawio architecture diagram + SVG
docs/publishing.md                what stays private when this goes public
scripts/audit-public.sh           pre-publish secret audit
iam/                              ready-to-attach policy documents
envs/prod/us-east-1/              root module - 10.100.0.0/16
envs/prod/us-east-2/              root module - 10.200.0.0/16
envs/prod/global-peering/         root module - cross-region TGW peering
modules/
  region-stack/                   composes one complete region
  tgw/                            Transit Gateway + 4 routing domains
  spoke-vpc/                      workload VPC + TGW attachment
  inspection-vpc/                 firewall VPC + NAT egress
  ingress-vpc/                    internet landing zone + NLB + IGW ingress routing
  gwlb/                           Gateway Load Balancer + GENEVE TG + endpoint service
  gwlb-endpoints/                 GWLB endpoints, one per AZ
  dxgw-attachment/                Direct Connect gateway association and hybrid routing
  panw-vmseries-asg/              VM-Series ASGs, launch templates, bootstrap bucket
  log-archive/                    flow log + access log bucket
  tgw-peering/                    inter-region peering and its routes
```

The two region roots are thin: they set the address plan and call
`modules/region-stack`. Everything structural lives in the modules.

---

## Diagram

`docs/diagrams/aws-network-platform.drawio` opens in [draw.io](https://app.diagrams.net),
the desktop app, or the VS Code Draw.io Integration extension. Three pages:

1. **Two-Region Overview** - both regions, TGW peering, the shared Direct
   Connect gateway, and where the internet attaches.
2. **Region Detail and Traffic Paths** - inspection and ingress VPC internals
   with the ingress path numbered 1-5, plus the east-west, egress and hybrid
   flows.
3. **Transit Gateway Route Domains** - what is in each of the five route
   tables and which attachment associates with it.

`aws-network-platform.svg` is a flat render of the same three pages for
viewing without draw.io. Both are generated from `scripts/gen-diagram.py`, so
edit the script rather than the output if the topology changes - though
hand-editing the .drawio is fine if you are done generating.

---

## Address plan

One `/22` per VPC, three AZs each. Every CIDR below is derived from
`region_supernet` with `cidrsubnet(supernet, 6, slot)` - inspection is slot 0,
ingress slot 1, spokes slot 2 upward. Point `region_supernet` at your own
space and the whole region moves; nothing else carries an address.
`terraform output vpc_cidr_plan` shows what a region resolved to.

The supernets below are the shipped defaults, not a recommendation - pick
your own.

| VPC | us-east-1 | us-east-2 |
|---|---|---|
| inspection | 10.100.0.0/22 | 10.200.0.0/22 |
| ingress | 10.100.4.0/22 | 10.200.4.0/22 |
| spoke-01 | 10.100.8.0/22 | 10.200.8.0/22 |
| spoke-02 | 10.100.12.0/22 | 10.200.12.0/22 |
| spoke-03 | 10.100.16.0/22 | 10.200.16.0/22 |
| spoke-04 | 10.100.20.0/22 | 10.200.20.0/22 |
| spoke-05 | 10.100.24.0/22 | 10.200.24.0/22 |
| spoke-06 | 10.100.28.0/22 | 10.200.28.0/22 |
| free | 10.100.32.0/19 + | 10.200.32.0/19 + |

Each region summarizes to a single `/16`, so the TGW route tables and the
firewall policy only ever need two supernets.

Subnets inside each VPC are derived the same way inside the modules. Adding a
spoke means incrementing `spoke_count`; it takes the next free /22.

**Spoke `/22`**

| Role | Size | Offsets |
|---|---|---|
| workload | /24 x3 | x.x.0.0, x.x.1.0, x.x.2.0 |
| tgw attachment | /28 x3 | x.x.3.0, x.x.3.16, x.x.3.32 |

**Inspection `/22`**

| Role | Size | Offsets |
|---|---|---|
| appliance data (eth0) | /26 x3 | x.x.0.0, x.x.0.64, x.x.0.128 |
| appliance mgmt (eth1) | /26 x3 | x.x.1.0, x.x.1.64, x.x.1.128 |
| public / NAT | /26 x3 | x.x.2.0, x.x.2.64, x.x.2.128 |
| gwlb endpoint | /28 x3 | x.x.3.0, x.x.3.16, x.x.3.32 |
| tgw attachment | /28 x3 | x.x.3.64, x.x.3.80, x.x.3.96 |

**Ingress `/22`**

| Role | Size | Offsets |
|---|---|---|
| public / NLB | /26 x3 | x.x.0.0, x.x.0.64, x.x.0.128 |
| private | /26 x3 | x.x.1.0, x.x.1.64, x.x.1.128 |
| gwlb endpoint | /28 x3 | x.x.3.0, x.x.3.16, x.x.3.32 |
| tgw attachment | /28 x3 | x.x.3.64, x.x.3.80, x.x.3.96 |

The `/22` plan tops out at three AZs; the VPC modules enforce that with a
variable validation rather than silently overlapping subnets.

---

## Transit Gateway routing

Default association and propagation are disabled. Four route tables:

| Domain | Associated attachments | Contents |
|---|---|---|
| `spoke` | the 6 spoke VPCs | static `0.0.0.0/0` -> inspection attachment; ingress VPC prefix propagated |
| `inspection` | inspection VPC | spoke + ingress prefixes propagated; on-premises prefixes propagated; remote supernet -> peering (inspecting region only) |
| `ingress` | ingress VPC | spoke prefixes propagated; static `0.0.0.0/0` -> inspection attachment |
| `peering` | TGW peering attachment | see cross-region below |
| `hybrid` | Direct Connect gateway attachment | static local supernet -> inspection attachment |

Two things carry the whole design:

- **`0.0.0.0/0` in the spoke table.** Spokes have no route to each other, so
  spoke-to-spoke, spoke-to-internet and anything unknown all land on the
  firewall.
- **Ingress propagated into the spoke table.** That prefix is more specific
  than the default, so NLB return traffic goes straight back to the ingress
  VPC instead of taking a second trip through inspection and breaking flow
  symmetry.

`appliance_mode_support = "enable"` is set on the inspection VPC attachment.
Without it the TGW can hash the two directions of a flow to different AZs and
the stateful firewall sees half a conversation.

---

## Traffic flows

**East-west (spoke to spoke)**

```
spoke A workload
  -> workload RT 0.0.0.0/0 -> TGW
  -> TGW spoke RT 0.0.0.0/0 -> inspection attachment
  -> inspection VPC tgw subnet, RT 0.0.0.0/0 -> AZ-local GWLB endpoint
  -> GWLB -> VM-Series (GENEVE 6081) -> GWLB
  -> gwlbe subnet RT 10.100.0.0/16 -> TGW
  -> TGW inspection RT (propagated spoke prefix)
  -> spoke B workload
```

**Internet ingress**

```
client -> IGW (ingress VPC)
  -> IGW ingress RT: NLB subnet prefix -> AZ-local GWLB endpoint
  -> GWLB -> VM-Series -> GWLB
  -> gwlbe subnet, NLB reached over the VPC local route
  -> NLB -> target IP in a spoke, public RT 10.100.0.0/16 -> TGW
  -> TGW ingress RT (propagated spoke prefix) -> spoke workload

return: spoke -> TGW spoke RT (ingress prefix, propagated) -> ingress VPC
        -> NLB -> public RT 0.0.0.0/0 -> GWLB endpoint -> VM-Series -> IGW
```

The NLB uses `target_type = "ip"` with `availability_zone = "all"`, which is
what lets it register backends that live in other VPCs across the TGW. Client
IP preservation is off by default, so spoke return traffic is addressed to the
NLB node and follows the propagated ingress prefix.

**Centralized egress**

```
spoke -> TGW -> inspection VPC tgw subnet -> GWLB endpoint -> VM-Series
      -> gwlbe RT 0.0.0.0/0 -> NAT gateway -> IGW

return: IGW -> NAT -> public RT 10.100.0.0/16 -> GWLB endpoint -> VM-Series
        -> gwlbe RT -> TGW -> spoke
```

**Cross-region**

Inspected once, in `us-east-1`, so both directions hit the same stateful
firewall:

```
us-east-1 (inspecting)          us-east-2 (bypass)
  spoke RT   10.200/16 -> insp    spoke RT   10.100/16 -> peering
  insp RT    10.200/16 -> peering peering RT local prefixes propagated
  peering RT 10.100/16 -> insp
```

`var.inspection_side` in `envs/prod/global-peering` and
`propagate_into_peering_route_table` in the region roots are two halves of the
same decision and must agree: the inspecting region sets propagation to
`false`. If it propagated its spoke prefixes into its own peering table, those
more specific routes would win over the static route to the firewall and
cross-region traffic would silently skip inspection.

**Hybrid / Direct Connect**

Optional, off by default. Set `dx_gateway_id` in a region root and that
region's TGW associates with the Direct Connect gateway; both regions
associate with the same one.

The two directions are not symmetric, which is where hybrid routing usually
goes wrong:

- **on-premises to AWS** is real BGP propagation. Routes learned from the
  customer router land in the TGW route tables you propagate the DX
  attachment into - here, `inspection` only.
- **AWS to on-premises** is not propagation at all. `allowed_prefixes` on the
  association is a static list, so it gets the summarized region supernet
  rather than eight /22s. AWS caps it at 200 prefixes per association.

The DX attachment lives in its own `hybrid` domain carrying one static route,
local supernet -> inspection attachment. The spoke table gets nothing: its
`0.0.0.0/0` already points at the firewall, and propagating on-premises
prefixes there would be more specific than that default and would send spoke
to on-premises traffic straight out the Direct Connect without inspection.
Same failure mode as propagating into the inspecting region's peering table.

Worth knowing before wiring it up: a DX gateway associates with at most 6
transit gateways, cannot hold virtual private gateway and transit gateway
associations at the same time, and requires a transit VIF rather than a
private one. Connecting one DX gateway to TGWs in different Regions requires
distinct ASNs, which the shipped 64512 / 64513 already satisfies.

---

## Firewalls

Palo Alto VM-Series, one Auto Scaling group per AZ.

- **`mgmt-interface-swap=enable`.** This makes `eth0` the data plane
  interface. It matters because a GWLB target group with
  `target_type = "instance"` registers the instance's primary ENI - without
  the swap it would register the management interface and never see GENEVE.
- **One ASG per AZ.** The launch template pins both ENIs to specific subnets,
  so an ASG cannot span AZs; each is declared with `availability_zones`
  instead of `vpc_zone_identifier`.
- **One-arm mode.** A single data plane interface receives and returns the
  tunnelled traffic.
- **Bootstrap** is an S3 bucket with the standard `config/`, `content/`,
  `license/`, `software/` prefixes. `config/init-cfg.txt` is generated from
  the module's Panorama variables. Drop in a `bootstrap.xml` with
  `vmseries.bootstrap_xml_path` or leave the firewalls to pull config from
  Panorama.
- **Cross-zone load balancing is off** on the GWLB, deliberately - combined
  with TGW appliance mode it keeps a flow on one AZ's firewall.

---

## Apply order

Permissions first - `docs/iam.md` covers the bootstrap role, the deploy role
and what each statement is guarding against.

```bash
# 1. State backends (once per account)
cd bootstrap
terraform init && terraform apply
# note the bucket and lock table names

# 2. Each region, independently
cd ../envs/prod/us-east-1
cp terraform.tfvars.example terraform.tfvars   # gitignored; fill in real values
cp backend.hcl.example backend.hcl
terraform init -backend-config=backend.hcl
terraform apply

cd ../us-east-2
terraform init -backend-config=backend.hcl
terraform apply

# 3. Peering, after both regions exist
cd ../global-peering
terraform init -backend-config=backend.hcl
terraform apply
```

---

## Before the first apply

- **Subscribe to the VM-Series Marketplace listing** matching
  `vmseries.license_type` (`byol`, `bundle1` or `bundle2`) in both regions, or
  the AMI lookup returns nothing. Pin `vmseries.ami_id` if you would rather
  not track `panos_version`.
- **Set `vmseries.mgmt_allowed_cidrs`** to your management network. It
  defaults to the region supernet in `terraform.tfvars`, which is broader than
  you want in production.
- **Set `log_archive_bucket_name`** to something globally unique in both
  `terraform.tfvars` files, and fill in the account ID in the `backend.hcl`
  files.
- **Supply `vm_auth_key` and `vm_series_auth_codes` from a secret store**, not
  from a checked-in tfvars file. They are marked `sensitive` but Terraform
  state still holds them.
- **Configure an interface management profile** on the VM-Series data plane
  interface that answers the GWLB health check. The default is
  `HTTP:80 /php/login.php`; change `gwlb_health_check_*` if you point it
  somewhere else. Until the firewalls pass health checks the GWLB blackholes
  traffic, so bring the fleet up before moving production routes.
- **The two TGW ASNs must stay distinct** (64512 / 64513 as shipped).
  Peering rejects matching ASNs.
- `ingress_listeners` ships empty. Add a listener with its spoke target IPs to
  publish a service.

## Known operational notes

- **Blast radius on `0.0.0.0/0`.** Every spoke default route points at the
  firewall. A GWLB with no healthy targets drops everything, so scale the ASGs
  to at least two per AZ before cutover and watch the
  `HealthyHostCount` metric on the GENEVE target group.
- **NAT gateways are per AZ** in the inspection VPC. That is three NAT
  gateways per region; set `enable_nat_gateway = false` in the inspection VPC
  module call if egress is handled elsewhere.
- **S3 gateway endpoints in the spokes** are on by default so bulk S3 traffic
  bypasses inspection. Turn off `enable_spoke_s3_gateway_endpoints` if policy
  requires S3 to be inspected too.
- **Access log delivery** grants both `delivery.logs.amazonaws.com` and the
  regional ELB service account, since us-east-1 and us-east-2 predate the
  newer delivery principal.

## Validation

`terraform validate` needs registry access, which the environment this was
scaffolded in did not have. What has been checked:

- `terraform fmt -recursive` clean - every file parses as HCL.
- Module wiring: every module input passed exists, every required input is
  supplied, every `module.x.y` reference resolves to a declared output, every
  `var.x` is declared, no unused variables.
- Address plan: all 16 VPCs and their 126 subnets computed from the
  `cidrsubnet()` expressions in the modules - no overlaps within a VPC,
  between VPCs, or across regions, and every subnet inside its VPC.

Run `terraform validate` and `terraform plan` against a real credential before
trusting the provider-level schema.
