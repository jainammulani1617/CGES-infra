Use terraform command using global variables files as shown below

terraform plan -var-file="global/{product}/{environment}/global_variables.tfvars"
terraform apply -var-file="global/{product}/{environment}/global_variables.tfvars"
terraform destroy -var-file="global/{product}/{environment}/global_variables.tfvars"