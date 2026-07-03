# Remote state in S3 with DynamoDB locking.
#
# Uses the same bucket and lock table as dev with a distinct state key.
# See environments/dev/backend.tf for the one-time bootstrap commands.
# Backend blocks cannot reference variables, so values are literal here.

terraform {
  backend "s3" {
    bucket         = "eks-platform-terraform-state"
    key            = "eks-platform/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
