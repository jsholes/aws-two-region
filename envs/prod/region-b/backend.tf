############################################################
# Remote state.
#
# Values are supplied at init time so the account ID does not have to
# be committed:
#
#   terraform init -backend-config=backend.hcl
############################################################

terraform {
  backend "s3" {}
}
