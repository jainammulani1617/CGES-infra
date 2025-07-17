global = {
  country             = ""
  environment         = "Prod"
  organization        = ""
  product             = "ASP"
  team                = "Application"
  region              = "ap-south-1"
  vpc_id              = "vpc-011287ec8e43a0194"
  cidr_blocks         = ["172.22.0.0/18"]
  bastion_ip          = "172.22.3.12/32"
  bastion_name        = "ASP-GSP-Prod-Key-Developer"
  bastion_user        = "ubuntu"
  bastion_key         = "/home/ubuntu/.ssh/ASP-GSP-Prod-Key-Developer.pem"
  bastion_sg_id       = "sg-0dc105341cf76e0f4"
  bastion_role_name   = "ASP-GSP-Prod-Role-BastionHost"
  account_id          = "053925025619"
  cygnet_cidr_blocks  = ["182.72.168.34/32", "61.12.66.2/32", "103.158.108.3/32", "14.97.193.214/32", "202.131.107.14/32", "202.131.112.106/32", "182.71.119.142/32", "202.131.101.34/32", "14.98.119.214/32"]
  availability_zones  = [
    "subnet-0939bde055f16ebaa",
    "subnet-096494e6087ba448b",
    "subnet-03647d6fb8712521b"
  ]
  public_availability_zones = [
    "subnet-0ce3d2a6e9383c8a0",
    "subnet-064a7f523bde642ba",
    "subnet-06a6d914d6334ec8e"
  ]
  eks_availability_zones = [
    "subnet-0326e763c3810209c",
    "subnet-0d198741aa01cd0e5",
    "subnet-09fe2efb30c34b819"
  ]
  s3_role            = "IN-CI-Prod-IAM-Postgres-S3-Access"
  cloudwatch_role    = "IN-CI-Prod-IAM-Cloudwatch-Access"
}