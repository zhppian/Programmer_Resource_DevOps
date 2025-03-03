# AWS Infrastructure with Terraform

This project uses Terraform to deploy and manage AWS infrastructure, including ECS, ECR, and related services. It also includes GitHub Actions for automated deployment and management.

## Project Structure

- **/terraform-ecs**: Contains Terraform configuration files for infrastructure setup.
- **/.github/workflows**: Contains GitHub Actions workflows for automated CI/CD.

## GitHub Actions Workflows

This project includes several GitHub Actions workflows to manage the infrastructure:

1. **ECS-apply.yml**: Runs `terraform apply` to deploy or update the infrastructure.
2. **ECS-destroy.yml**: Runs `terraform destroy` to tear down the infrastructure.
3. **ECR-update.yml**: Redeploys ECS service with the updated ECR image, without reapplying all AWS resources.

## How to Use

### Setup

1. Clone the repository:
   ```bash
   git clone <repository_url>
   cd <repository_name>
   ```

2. Configure AWS credentials as repository secrets in GitHub.

3. Initialize Terraform:
   ```bash
   cd terraform-ecs
   terraform init
   ```

### Deploy Infrastructure

Run the `ECS-apply.yml` workflow to apply Terraform changes:

- Navigate to the Actions tab in your GitHub repository.
- Select **ECS-apply** and click **Run workflow**.

### Destroy Infrastructure

Run the `ECS-destroy.yml` workflow to tear down the infrastructure:

- Navigate to the Actions tab.
- Select **ECS-destroy** and click **Run workflow**.

### Redeploy Updated ECR Image

If you update the Docker image in ECR, run the `ECR-update.yml` workflow:

- This updates ECS to use the latest image without affecting other AWS resources.
- Navigate to the Actions tab.
- Select **ECR-update** and click **Run workflow**.

## Terraform Commands

Manually apply or destroy infrastructure if needed:

- Apply changes:
   ```bash
   terraform apply
   ```

- Destroy infrastructure:
   ```bash
   terraform destroy
   ```

## Best Practices

- Use environment-specific Terraform workspaces.
- Review changes with `terraform plan` before applying.
- Monitor ECS service logs for troubleshooting.

Let me know if you’d like me to refine this further or add more details! 🚀

