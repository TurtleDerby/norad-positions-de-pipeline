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


# -----------------------------------------------------------------
# IAM Role for Lambda functions with necessary permissions
# -----------------------------------------------------------------
resource "aws_iam_role" "lambda_role" {
  name = "${local.project}-${local.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { # Allow Lambda service to assume this role
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# -----------------------------------------------------------------
# Attach AWSLambdaBasicExecutionRole policy to the Lambda role created above
# -----------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# -----------------------------------------------------------------
# Create custom IAM policy for IAM functions to access S3 and Secrets Manager, and attach it to the Lambda role
# -----------------------------------------------------------------
resource "aws_iam_policy" "lambda_policy" {
    name = "${local.project}-${local.environment}-lambda-policy"

    policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Effect = "Allow"
            Action = [
                "s3:PutObject"
            ]
            Resource = "${aws_s3_bucket.data_lake.arn}/*"
        },
        {
            Effect = "Allow"
            Action = [
                "secretsmanager:GetSecretValue",
            ]
            Resource = "*"
        }
    ]
    })
}

# -----------------------------------------------------------------
# Attach the custom IAM policy to the Lambda role
# -----------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "lambda_attach_custom" {
    role = aws_iam_role.lambda_role.name
    policy_arn = aws_iam_policy.lambda_policy.arn
}

# -----------------------------------------------------------------
# Lambda function for ingesting positions data into the data lake
# -----------------------------------------------------------------
resource "aws_lambda_function" "ingest_positions" {
    function_name = "${local.project}-${local.environment}-ingest"
    role = aws_iam_role.lambda_role.arn
    handler = "app.handler"
    runtime = "python3.11"
    timeout = 30

    filename = "${path.module}/../../../ingest/lambda/deployment.zip"
    source_code_hash = filebase64sha256("${path.module}/../../../ingest/lambda/deployment.zip")

    environment {
      variables = {
        DATA_LAKE_BUCKET = aws_s3_bucket.data_lake.bucket
      }
    }
}