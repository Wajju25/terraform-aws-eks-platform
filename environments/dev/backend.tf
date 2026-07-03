# Remote state in S3 with DynamoDB locking.
#
# Bootstrap once per AWS account (bucket and table names must be globally
# unique — adjust to your account, then update this block to match):
#
#   aws s3api create-bucket --bucket <your-tf-state-bucket> --region us-east-1
#   aws s3api put-bucket-versioning --bucket <your-tf-state-bucket> \
#     --versioning-configuration Status=Enabled
#   aws s3api put-bucket-encryption --bucket <your-tf-state-bucket> \
#     --server-side-encryption-configuration \
#     '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms"}}]}'
#   aws dynamodb create-table --table-name terraform-locks \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST
#
# Backend blocks cannot reference variables, so values are literal here.

terraform {
  backend "s3" {
    bucket         = "eks-platform-terraform-state"
    key            = "eks-platform/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
