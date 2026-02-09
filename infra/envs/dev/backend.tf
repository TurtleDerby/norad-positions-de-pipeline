terraform{
    backend "s3" {
        bucket         = "norad-tf-state-deportfoliov0001"
        key            = "envs/dev/terraform.tfstate"
        region         = "us-east-1"
        dynamodb_table = "terraform-locks"
        profile        = "terraform-admin-dev"
        encrypt        = true
    }
}