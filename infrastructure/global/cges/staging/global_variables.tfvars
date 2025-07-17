global = {
  country                 = "SG"
  environment             = "Stag"
  organization            = "CI"
  product                 = "CGES"
  team                    = "Application"
  region                  = "ap-singapore-1"
  tenancy_ocid        = "ocid1.tenancy.oc1..aaaaaaaatospw7lvwbx2bsbasjhnbbteysanws3a4bcljynu7r77blztki7a"
  compartment_ocid    = "ocid1.compartment.oc1..aaaaaaaas4ijhtzs6r2iusnmx27pabhoc72c7kkpvvhxlw7ccsul4vywmqiq"
  vcn_id                  = "ocid1.vcn.oc1.ap-singapore-1.amaaaaaa6vtk4diao7nmbkdpw6mbyy255pr5sh2a6ekpckikk6h5cguiw2fq"
  cidr_blocks             = ["172.21.0.128/25","172.21.2.0/24" ,"172.21.6.0/23"]
  bastion_ip   ="139.185.52.245"
  bastion_name = "OCI-CGI-Bastion-02"
  bastion_user = "ubuntu"
  bastion_key  = "/home/ubuntu/.ssh/"
  # bastion_sg_id           = "sg-01c1d6267d1f05977"
  # bastion_role_name       = "ASP-GSP-Stag-Role-BastionHost"
  # bastion_iam_role_name   = "ASP-GSP-Stag-Role-BastionHost"
  # account_id              = "801214744976"
   cygnet_cidr_blocks = ["182.72.168.34/32", "61.12.66.2/32", "103.158.108.3/32", "14.97.193.214/32", "202.131.107.14/32", "202.131.112.106/32", "182.71.119.142/32", "202.131.101.34/32", "14.98.119.214/32"]
  private_availability_domains = [
     "ocid1.subnet.oc1.ap-singapore-1.aaaaaaaapqphw4hb2whoj3trtkqeniwaudzot3faum276542jgmjvnd2a3kq"
   ]
  public_availability_domains = [
     "ocid1.subnet.oc1.ap-singapore-1.aaaaaaaa2whkjhh542enxz5zd5tucjlbmz3xzuv4ylo564t3ekf7nej5p7nq"
   ]
   eks_availability_domains = [
     "ocid1.subnet.oc1.ap-singapore-1.aaaaaaaa3koqorezrxah5jzsw44ajz3juk2ce6z5n35trpaq3ccormuk3cqq"
   ]
  # s3_role         = "IN-CI-Stag-IAM-Postgres-S3-Access"
  # cloudwatch_role = "IN-CI-Stag-IAM-Cloudwatch-Access"
  common_tags = {
    "Environment" = "staging"
    "Project"     = "cges"
    "ManagedBy"   = "terraform"
  }
}


