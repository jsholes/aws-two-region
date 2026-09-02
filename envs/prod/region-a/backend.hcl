# Fill in from the bootstrap stack's outputs, then:
#   terraform init -backend-config=backend.hcl
bucket         = "netplat-tfstate-<ACCOUNT_ID>-us-east-1"
key            = "prod/us-east-1/network/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "netplat-tfstate-locks"
encrypt        = true
