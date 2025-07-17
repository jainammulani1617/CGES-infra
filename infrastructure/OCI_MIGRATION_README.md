# AWS to OCI Migration Guide

This document outlines the migration of the high-level AWS infrastructure setup (RabbitMQ and Redis servers with load balancers, HAProxy, and monitoring) to Oracle Cloud Infrastructure (OCI).

## Overview

The original AWS setup included:
- **Redis Cluster**: 6 EC2 instances across 3 availability zones
- **RabbitMQ HA**: 2 EC2 instances with HAProxy load balancing
- **AWS Network Load Balancer (NLB)**: For RabbitMQ traffic distribution
- **Security Groups**: For network access control
- **CloudWatch Agent**: For monitoring and logging
- **Bastion Host**: For secure access to private instances

## OCI Equivalent Architecture

The OCI setup maintains the same functionality with these equivalent components:

| AWS Component | OCI Equivalent | Notes |
|---------------|----------------|-------|
| EC2 Instances | Compute Instances | Using VM.Standard.E4.Flex shapes |
| VPC | Virtual Cloud Network (VCN) | |
| Availability Zones | Availability Domains | |
| Security Groups | Network Security Groups (NSG) | |
| Network Load Balancer | Load Balancer (Flexible shape) | |
| CloudWatch Agent | OCI Monitoring Agent | Custom monitoring setup |
| AMI | Oracle Linux 8 Image | Using Oracle-provided images |
| EBS Volumes | Block Volumes | Encrypted by default |

## Key Changes Made

### 1. Provider Configuration
```hcl
# Before (AWS)
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.67"
    }
  }
}

# After (OCI)
terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.26.0"
    }
  }
}
```

### 2. Resource Mappings

#### Compute Instances
- **AWS**: `aws_instance` → **OCI**: `oci_core_instance`
- Added shape configuration with OCPU and memory specifications
- Changed from key pairs to SSH authorized keys in metadata

#### Networking
- **AWS**: `aws_security_group` → **OCI**: `oci_core_network_security_group`
- **AWS**: Inline ingress/egress rules → **OCI**: Separate `oci_core_network_security_group_security_rule` resources

#### Load Balancing
- **AWS**: `aws_lb` (NLB) → **OCI**: `oci_load_balancer` (Flexible)
- **AWS**: Target Groups → **OCI**: Backend Sets
- **AWS**: Target Group Attachments → **OCI**: Backend resources

### 3. Variable Updates

Global variables updated to OCI terminology:
- `vpc_id` → `vcn_id`
- `account_id` → `compartment_id`
- `availability_zones` → `availability_domains`

### 4. Image and Instance Configuration

- **AMI**: Changed from Ubuntu AMI to Oracle Linux 8 image OCID
- **User**: Changed from `ubuntu` to `opc` (Oracle Public Cloud default user)
- **Instance Types**: Mapped AWS instance types to OCI shapes:
  - `t3a.medium` → `VM.Standard.E4.Flex` (2 OCPU, 16GB RAM)
  - `r6a.xlarge` → `VM.Standard.E4.Flex` (4 OCPU, 32GB RAM)
  - `r6a.large` → `VM.Standard.E4.Flex` (2 OCPU, 16GB RAM)

### 5. Monitoring Setup

- Replaced CloudWatch Agent with OCI Monitoring Agent
- Updated configuration paths and service management
- Modified Ansible playbooks for OCI-compatible monitoring setup

## Configuration Steps

### 1. Prerequisites

1. **OCI Account**: Ensure you have an active OCI tenancy
2. **OCI CLI**: Install and configure OCI CLI with appropriate credentials
3. **Terraform**: Version >= 1.2.0
4. **Network Setup**: Pre-existing VCN with subnets in multiple availability domains
5. **SSH Keys**: Generate SSH key pair for instance access

### 2. Configure Variables

1. Copy the example variables file:
   ```bash
   cp infrastructure/global/cges/production/global_variables.tfvars.example \
      infrastructure/global/cges/production/global_variables.tfvars
   ```

2. Fill in the required values:
   - `region`: Your OCI region (e.g., "us-ashburn-1")
   - `compartment_id`: Target compartment OCID
   - `vcn_id`: Virtual Cloud Network OCID
   - `availability_domains`: List of subnet OCIDs across ADs
   - `bastion_ip`: IP of your bastion host
   - `bastion_key`: Path to SSH private key

### 3. OCI Authentication

Set up OCI authentication using one of these methods:

#### Option A: OCI CLI Config
```bash
oci setup config
```

#### Option B: Environment Variables
```bash
export TF_VAR_tenancy_ocid="ocid1.tenancy.oc1..."
export TF_VAR_user_ocid="ocid1.user.oc1..."
export TF_VAR_fingerprint="your:key:fingerprint"
export TF_VAR_private_key_path="/path/to/private/key"
```

### 4. Deploy Infrastructure

```bash
cd infrastructure/global/cges/production
terraform init
terraform plan -var-file="global_variables.tfvars"
terraform apply -var-file="global_variables.tfvars"
```

## Security Considerations

### Network Security Groups (NSG)
The following ports are configured:

**Redis NSG**:
- Port 22: SSH from bastion host
- Port 6379: Redis communication from application subnets
- Port 16379: Redis cluster communication

**RabbitMQ NSG**:
- Port 22: SSH from bastion host
- Port 5672: RabbitMQ AMQP (via HAProxy)
- Port 5673: Direct RabbitMQ AMQP
- Port 7000: HAProxy statistics
- Port 15672: RabbitMQ Management UI (via HAProxy)
- Port 15673: Direct RabbitMQ Management UI

### Encryption
- All block volumes are encrypted by default
- Network traffic encryption in transit is enabled
- SSH keys are used for instance access (no passwords)

## Monitoring and Logging

### OCI Monitoring Integration
- Custom namespace: `custom_metrics`
- Metrics collected: CPU, Memory, Disk, Network
- Collection interval: 60 seconds
- System logs forwarded to OCI Logging service

### Available Metrics
- CPU usage (idle, user, system)
- Memory utilization percentage
- Disk usage percentage
- Network connections (established, time_wait)

## Load Balancer Configuration

### RabbitMQ Load Balancer
- **Type**: Flexible Load Balancer (private)
- **Bandwidth**: 10-100 Mbps (auto-scaling)
- **Health Checks**: TCP on ports 5672 and 15672
- **Backend Policy**: Round Robin
- **Listeners**: 
  - Port 5672: RabbitMQ AMQP traffic
  - Port 15672: Management UI traffic

## Differences from AWS Implementation

1. **Availability Domains**: OCI uses ADs instead of AZs, requiring explicit subnet specification
2. **Flexible Shapes**: OCI allows custom OCPU/memory configuration vs fixed AWS instance types
3. **NSG Rules**: OCI requires separate rule resources vs inline AWS security group rules
4. **Load Balancer**: OCI uses unified load balancer vs separate NLB/ALB in AWS
5. **Monitoring**: Custom OCI monitoring setup vs managed CloudWatch service
6. **Image Management**: Using Oracle-provided images vs custom AMIs

## Cost Optimization

- **Flexible Shapes**: Right-size compute resources based on actual requirements
- **Burstable Performance**: Utilize baseline performance with bursting capabilities
- **Reserved Instances**: Consider OCI Reserved Capacity for predictable workloads
- **Storage Optimization**: Use appropriate block volume performance tiers

## Troubleshooting

### Common Issues

1. **Authentication Errors**:
   - Verify OCI CLI configuration: `oci iam user get --user-id $OCI_USER_OCID`
   - Check policy permissions for the compartment

2. **Network Connectivity**:
   - Verify subnet configuration and route tables
   - Check NSG rules and security lists
   - Ensure internet gateway/NAT gateway setup for outbound access

3. **Instance Launch Failures**:
   - Verify compartment quotas and limits
   - Check availability domain capacity
   - Ensure SSH key format is correct

4. **Load Balancer Issues**:
   - Verify backend health checks
   - Check security rules for health check traffic
   - Ensure backends are in correct subnets

### Support Resources

- **OCI Documentation**: https://docs.oracle.com/en-us/iaas/
- **Terraform OCI Provider**: https://registry.terraform.io/providers/oracle/oci/
- **OCI Community**: https://cloudcustomerconnect.oracle.com/

## Migration Validation

After deployment, validate the migration by:

1. **Connectivity Tests**: Verify SSH access through bastion host
2. **Service Health**: Check Redis cluster formation and RabbitMQ clustering
3. **Load Balancer**: Test traffic distribution and health checks
4. **Monitoring**: Confirm metrics collection and alerting
5. **High Availability**: Test failover scenarios

## Rollback Plan

If rollback to AWS is needed:
1. Restore original AWS configuration files from version control
2. Update variable files with AWS-specific values
3. Re-deploy using AWS provider
4. Migrate data from OCI to AWS if necessary

---

**Note**: This migration maintains functional equivalence while leveraging OCI-native services and capabilities. All original functionality including high availability, load balancing, monitoring, and security controls are preserved in the OCI implementation.