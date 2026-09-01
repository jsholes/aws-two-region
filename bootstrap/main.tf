############################################################
# Terraform state backends
#
# One versioned, encrypted S3 bucket and one DynamoDB lock table per
# region. Region roots keep their state in their own region so a
# regional outage cannot block that region's recovery work.
############################################################

data "aws_caller_identity" "use1" {
  provider = aws.use1
}

locals {
  account_id = data.aws_caller_identity.use1.account_id

  use1_bucket = "${var.org_prefix}-tfstate-${local.account_id}-us-east-1"
  use2_bucket = "${var.org_prefix}-tfstate-${local.account_id}-us-east-2"
  lock_table  = "${var.org_prefix}-tfstate-locks"
}

############################################################
# us-east-1
############################################################

resource "aws_s3_bucket" "use1" {
  provider = aws.use1

  bucket = local.use1_bucket

  tags = { Name = local.use1_bucket }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "use1" {
  provider = aws.use1

  bucket = aws_s3_bucket.use1.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "use1" {
  provider = aws.use1

  bucket = aws_s3_bucket.use1.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "use1" {
  provider = aws.use1

  bucket = aws_s3_bucket.use1.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "use1" {
  provider = aws.use1

  name         = local.lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = { Name = local.lock_table }

  lifecycle {
    prevent_destroy = true
  }
}

############################################################
# us-east-2
############################################################

resource "aws_s3_bucket" "use2" {
  provider = aws.use2

  bucket = local.use2_bucket

  tags = { Name = local.use2_bucket }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "use2" {
  provider = aws.use2

  bucket = aws_s3_bucket.use2.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "use2" {
  provider = aws.use2

  bucket = aws_s3_bucket.use2.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "use2" {
  provider = aws.use2

  bucket = aws_s3_bucket.use2.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "use2" {
  provider = aws.use2

  name         = local.lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = { Name = local.lock_table }

  lifecycle {
    prevent_destroy = true
  }
}
