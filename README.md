# Terraform AWS ECS Deployment

This project provisions a complete AWS infrastructure using Terraform to deploy a containerized application with a frontend and two backend services using ECS Fargate. It includes ECR repositories, ECS task definitions, security groups, load balancers, and IAM roles.

## Features

- **State Management:** Terraform state stored in S3 with encryption enabled.
- **ECR Repositories:** Frontend, backend, and backend (port 5002) repositories with image scanning and lifecycle policies.
- **IAM Roles:** ECS task execution role with policies for ECS and S3 access.
- **ECS Cluster & Tasks:** Fargate tasks for frontend and backend services with log configuration for CloudWatch.
- **Networking:** Security groups for HTTP/HTTPS access, subnets, and default VPC configuration.
- **Load Balancer:** Application Load Balancer with target groups and health checks.

## Infrastructure Overview

- **Terraform Backend:** S3 bucket for state storage
- **Providers:** AWS
- **Resource Types:** ECR, ECS, IAM, VPC, Security Groups, ALB

## Usage

1. **Initialize Terraform:**

   ```bash
   terraform init
   ```

2. **Plan Deployment:**

   ```bash
   terraform plan
   ```

3. **Apply Changes:**

   ```bash
   terraform apply
   ```

4. **Destroy Resources:**

   ```bash
   terraform destroy
   ```

## Variables

- `app_name`: Application name prefix
- `region`: AWS region
- `container_cpu`: CPU units for ECS containers
- `container_memory`: Memory for ECS containers
- `frontend_port`, `backend_port`, `backend_second_port`: Service ports

## Author

This infrastructure was built and managed by me, leveraging Terraform and AWS services to create a scalable, secure, and highly available application environment.

Would you like me to refine this, add diagrams, or tailor it more to highlight your strengths? Let me know! 🚀

