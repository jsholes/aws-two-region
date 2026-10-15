provider "aws" {
  region = var.requester_region
  alias  = "requester"

  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  region = var.accepter_region
  alias  = "accepter"

  default_tags {
    tags = local.tags
  }
}
