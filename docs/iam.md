# IAM for this platform

Three distinct sets of permissions, easy to conflate:

1. **Bootstrap role** - creates the state buckets and lock tables. Run once,
   then park it.
2. **Deploy role** - what Terraform assumes to build and maintain the
   network. This is the big one.
3. **Runtime roles** - already defined in Terraform, created by the apply.
   Nothing to hand-build.

Policy documents live in `iam/` with `<ACCOUNT_ID>` placeholders. Render them
into `iam/generated/`, which is gitignored, so the real account ID never lands
in a tracked file:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
mkdir -p iam/generated
for f in iam/*.json; do
  sed "s/<ACCOUNT_ID>/$ACCOUNT_ID/g" "$f" > "iam/generated/$(basename "$f")"
done
```

---

## 1. Bootstrap role

Attach `iam/bootstrap.json`. Scope is `netplat-tfstate-*` buckets and the
`netplat-tfstate-locks` DynamoDB tables, nothing else.

`dynamodb:UpdateContinuousBackups` is the one people miss - the bootstrap
stack enables point-in-time recovery on the lock tables.

---

## 2. Deploy role

Five managed policies, split to stay under the 6,144-character limit per
policy and to keep the blast radius readable:

| Policy | Covers |
|---|---|
| `deploy-1-network.json` | VPCs, subnets, IGW/NAT/EIP, route tables and routes, security groups, ENIs, flow logs |
| `deploy-2-tgw-endpoints.json` | Transit Gateway, its route tables, VPC and peering attachments, VPC endpoints and the GWLB endpoint service |
| `deploy-3-lb-asg.json` | GWLB and NLB, target groups, listeners, launch templates, Auto Scaling groups, scaling-policy alarms |
| `deploy-4-iam-s3.json` | The VM-Series role and instance profile, `PassRole`, service-linked roles, log archive and bootstrap buckets |
| `deploy-5-state.json` | Read/write the region state objects and take the DynamoDB lock |

Trust policy: `iam/trust-policy.json`, MFA-gated. Swap the principal for your
CI role's ARN if a pipeline applies this.

### Things worth understanding rather than pasting

**`iam:PassRole` is the privilege escalation risk.** The deploy role can
create an IAM role and attach it to an instance. It is scoped two ways -
`Resource` limited to `prod-use*-vmseries-role`, and
`iam:PassedToService = ec2.amazonaws.com`. Do not widen the resource to `*`;
that turns the deploy role into "make any role, attach it to a box I control,
assume it."

**`iam:CreateServiceLinkedRole` is first-run only.** ELB, Auto Scaling and
Transit Gateway each need their service-linked role to exist. If the account
already has all three, the statement is inert and can be dropped.

**The region condition is the cheap guardrail.** Every EC2, ELB and
autoscaling statement carries
`aws:RequestedRegion in [us-east-1, us-east-2]`. Add regions here when you add
regions to the platform, or the apply fails with a confusing AccessDenied.

**Describe is unscoped.** `ec2:Describe*`, `elasticloadbalancing:Describe*`
and `autoscaling:Describe*` do not support resource-level permissions, so they
are `*`. That is read-only inventory, and Terraform genuinely needs all of it
for refresh.

**Bucket name patterns must match your tfvars.** `deploy-4` scopes S3 to
`netplat-logs-*` and `prod-use*-vmseries-bootstrap-*`. If you change
`log_archive_bucket_name` or `name_prefix`, update the ARNs to match or the
apply fails on bucket creation.

### Not in the deploy role, on purpose

**Marketplace subscription.** Accepting the VM-Series terms is a billing
decision, so it stays a one-time human action in the console. If you do want
it automated, that principal needs:

```
aws-marketplace:Subscribe
aws-marketplace:ViewSubscriptions
ec2:DescribeImages
```

**KMS**, unless you set `vmseries.ebs_kms_key_id`. With a customer-managed key
the deploy role and the Auto Scaling service-linked role both need access to
it. Add to the deploy role:

```json
{
  "Effect": "Allow",
  "Action": [
    "kms:DescribeKey",
    "kms:CreateGrant",
    "kms:GenerateDataKeyWithoutPlaintext"
  ],
  "Resource": "arn:aws:kms:*:<ACCOUNT_ID>:key/<KEY_ID>",
  "Condition": {
    "StringEquals": { "kms:ViaService": ["ec2.us-east-1.amazonaws.com", "ec2.us-east-2.amazonaws.com"] }
  }
}
```

and grant the key to `AWSServiceRoleForAutoScaling` separately - the ASG, not
Terraform, is what launches the encrypted volumes.

**`ec2:RunInstances` / `TerminateInstances`.** Terraform never launches an
instance here; the Auto Scaling service-linked role does. If you see
AccessDenied on RunInstances, something is wrong with the launch template, not
with this policy.

---

## 3. Runtime roles (created by the apply)

**VM-Series instance role** - `modules/panw-vmseries-asg/main.tf`. Read on the
bootstrap bucket, `cloudwatch:PutMetricData`, and read-only `ec2:Describe*`
for the PAN-OS AWS plugin's dynamic address groups. Nothing else. If you add
Panorama plugin features that mutate AWS state, they go here, not in the
deploy role.

**Flow log delivery** needs no role - the S3 destination is authorized by the
bucket policy in `modules/log-archive`, granting
`delivery.logs.amazonaws.com`, and separately the regional ELB service account
for NLB access logs.

---

## Verifying before you commit to it

```bash
# dry run the deploy role against a real plan
aws sts assume-role --role-arn arn:aws:iam::<ACCOUNT_ID>:role/netplat-deploy \
  --role-session-name plan-check
cd envs/prod/us-east-1
terraform init -backend-config=backend.hcl
terraform plan
```

A clean plan only proves read access. Use IAM Access Analyzer's policy
validation on each JSON, and run the first apply against a scratch account if
you have one - the first real apply is where `PassRole` and the
service-linked roles surface.
