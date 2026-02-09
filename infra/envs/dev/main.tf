# -----------------------------------------------------------------
# Terraform configuration for the development environment
# -----------------------------------------------------------------
locals {
    project = "norad-positions"
    environment = "dev"
    region = "us-east-1"
}

resource "random_id" "bucket_suffix" {
    byte_length = 4
}

# -----------------------------------------------------------------
# S3 Bucket for data lake and encryption configuration
# -----------------------------------------------------------------
resource "aws_s3_bucket" "data_lake" {
    bucket = "${local.project}-${local.environment}-data-lake-${random_id.bucket_suffix.hex}"
    
    lifecycle {
        prevent_destroy = true
    }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
    bucket = aws_s3_bucket.data_lake.id

    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }
}

# -----------------------------------------------------------------
# S3 Bucket for Athena query results and encryption configuration
# -----------------------------------------------------------------
resource "aws_s3_bucket" "athena_results" {
    bucket = "${local.project}-${local.environment}-athena-results-${random_id.bucket_suffix.hex}"
    
    lifecycle {
        prevent_destroy = true
    }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
    bucket = aws_s3_bucket.athena_results.id

    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }
}

# -----------------------------------------------------------------
# Athena Workgroup configuration
# -----------------------------------------------------------------
resource "aws_athena_workgroup" "primary" {
    name = "${local.project}-${local.environment}-workgroup"

    configuration {
        enforce_workgroup_configuration = true

        result_configuration {
            output_location = "s3://${aws_s3_bucket.athena_results.bucket}/results/"
        }
    }
}


# -----------------------------------------------------------------
# Glue Catalog Database configuration
# -----------------------------------------------------------------
resource "aws_glue_catalog_database" "norad" {
    name = "${replace(local.project, "-", "_")}_${local.environment}"
}

data "aws_caller_identity" "current" {}

output "data_lake_bucket" {
    value = aws_s3_bucket.data_lake.bucket
}

output "athena_workgroup" {
    value = aws_athena_workgroup.primary.name
}

output "glue_database" {
    value = aws_glue_catalog_database.norad.name
}