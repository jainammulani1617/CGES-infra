variable "global" {
  type = object({
    country                   = string
    environment               = string
    organization              = string
    product                   = string
    team                      = string
    region                    = string
    tenancy_id              = string
    subnet_ocid           = string
    compartment_id          = string
    vcn_id                    = string
    cidr_blocks               = list(string)
    bastion_ip                = string
    bastion_name              = string
    bastion_user              = string
    bastion_key               = string
    # bastion_sg_id             = string
    # bastion_role_name         = string
    # bastion_iam_role_name     = string
    # account_id                = string
    cygnet_cidr_blocks        = list(string)
    availability_domain     = string
    private_availability_domains        = list(string)
    public_availability_domains = list(string)
    oke_availability_domains    = list(string)
    # s3_role                   = string
    # cloudwatch_role           = string
  })
}