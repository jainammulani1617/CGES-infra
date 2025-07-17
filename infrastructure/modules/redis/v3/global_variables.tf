variable "global" {
  type = object({
    environment          = string
    product              = string
    team                 = string
    region               = string
    vcn_id               = string
    cidr_blocks          = list(string)
    bastion_ip           = string
    bastion_name         = string
    bastion_user         = string
    bastion_key          = string
    availability_domains = list(string)
    compartment_id       = string
  })
  description = "Pass global variables file as terraform command argument. Example -var-file=\"../global/{product}/global_variables.tfvars\""
}
