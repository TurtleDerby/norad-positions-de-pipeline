terraform {
  required_version = ">= 1.5.0"
}

provider "aws" {
  profile = "terraform-admin-dev"
  region  = "us-east-1"
}

resource "aws_s3_bucket" "tf_state" {
  bucket = "norad-tf-state-deportfoliov0001"

  lifecycle   {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration   {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "tf_lock" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
