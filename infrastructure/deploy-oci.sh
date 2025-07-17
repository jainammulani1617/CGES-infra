#!/bin/bash

# OCI Infrastructure Deployment Script
# This script helps deploy the RabbitMQ and Redis infrastructure on OCI

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/global/cges/production"
TFVARS_FILE="global_variables.tfvars"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install Terraform >= 1.2.0"
        exit 1
    fi
    
    # Check terraform version
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
    log_info "Terraform version: $TERRAFORM_VERSION"
    
    # Check if OCI CLI is installed
    if ! command -v oci &> /dev/null; then
        log_warning "OCI CLI is not installed. You may need to configure OCI authentication manually."
    else
        log_info "OCI CLI is available"
    fi
    
    # Check if tfvars file exists
    if [[ ! -f "${TERRAFORM_DIR}/${TFVARS_FILE}" ]]; then
        log_error "Variables file not found: ${TERRAFORM_DIR}/${TFVARS_FILE}"
        log_info "Please copy and configure the example file:"
        log_info "  cp ${TERRAFORM_DIR}/${TFVARS_FILE}.example ${TERRAFORM_DIR}/${TFVARS_FILE}"
        log_info "  # Edit the file with your OCI configuration"
        exit 1
    fi
    
    log_success "Prerequisites check completed"
}

terraform_init() {
    log_info "Initializing Terraform..."
    cd "${TERRAFORM_DIR}"
    terraform init
    log_success "Terraform initialized"
}

terraform_plan() {
    log_info "Creating Terraform plan..."
    cd "${TERRAFORM_DIR}"
    terraform plan -var-file="${TFVARS_FILE}" -out=tfplan
    log_success "Terraform plan created (saved as tfplan)"
}

terraform_apply() {
    log_info "Applying Terraform configuration..."
    cd "${TERRAFORM_DIR}"
    
    if [[ -f "tfplan" ]]; then
        terraform apply tfplan
    else
        log_warning "No plan file found, running apply with auto-approve"
        terraform apply -var-file="${TFVARS_FILE}" -auto-approve
    fi
    
    log_success "Infrastructure deployed successfully!"
    
    # Show outputs
    log_info "Infrastructure outputs:"
    terraform output
}

terraform_destroy() {
    log_warning "This will destroy ALL infrastructure resources!"
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm
    
    if [[ $confirm == "yes" ]]; then
        log_info "Destroying infrastructure..."
        cd "${TERRAFORM_DIR}"
        terraform destroy -var-file="${TFVARS_FILE}"
        log_success "Infrastructure destroyed"
    else
        log_info "Destroy cancelled"
    fi
}

show_help() {
    echo "OCI Infrastructure Deployment Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  init     - Initialize Terraform"
    echo "  plan     - Create Terraform plan"
    echo "  apply    - Apply Terraform configuration"
    echo "  destroy  - Destroy infrastructure"
    echo "  check    - Check prerequisites only"
    echo "  help     - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 check      # Check prerequisites"
    echo "  $0 init       # Initialize Terraform"
    echo "  $0 plan       # Create deployment plan"
    echo "  $0 apply      # Deploy infrastructure"
    echo ""
}

# Main script logic
case "${1:-help}" in
    check)
        check_prerequisites
        ;;
    init)
        check_prerequisites
        terraform_init
        ;;
    plan)
        check_prerequisites
        terraform_init
        terraform_plan
        ;;
    apply)
        check_prerequisites
        terraform_init
        terraform_apply
        ;;
    destroy)
        check_prerequisites
        terraform_destroy
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac