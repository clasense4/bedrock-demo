# Backend Infrastructure

Terraform configuration for the backend API (Lambda + API Gateway).

## Quick Start

1. **Deploy Bedrock infrastructure first** (if not already done):
   ```bash
   cd infra/bedrock
   terraform init
   terraform apply
   ```

2. **Build Lambda package**:
   ```bash
   make prod-backend-build
   ```

3. **Deploy backend**:
   ```bash
   cd infra/backend
   cp terraform.tfvars.example terraform.tfvars
   terraform init
   terraform apply
   ```

## Knowledge Base ID

The backend automatically reads the `knowledge_base_id` from the Bedrock Terraform state (`../bedrock/terraform.tfstate`).

If you need to override it, set it in `terraform.tfvars`:
```hcl
knowledge_base_id = "your-kb-id-here"
```

## Outputs

After deployment:
```bash
terraform output
```

Shows API endpoints, Lambda details, and the Knowledge Base ID being used.
