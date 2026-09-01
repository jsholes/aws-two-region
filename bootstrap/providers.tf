############################################################
# The bootstrap stack keeps its own state locally (or wherever you
# point it) because it is what creates the remote state backends.
# Run it once per account, then commit the generated bucket and table
# names into each region's backend.tf.
############################################################

provider "aws" {
  region = "us-east-1"
  alias  = "use1"

  default_tags {
    tags = var.tags
  }
}

provider "aws" {
  region = "us-east-2"
  alias  = "use2"

  default_tags {
    tags = var.tags
  }
}
