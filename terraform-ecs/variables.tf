# variables.tf file

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-3"
}

variable "app_name" {
  description = "Application name used for naming resources"
  type        = string
  default     = "program-resource"
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "programresourcehub.com"
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate"
  type        = string
  default     = ""
}

variable "frontend_port" {
  description = "Port for frontend container"
  type        = number
  default     = 5173
}

variable "backend_port" {
  description = "Port for main backend container"
  type        = number
  default     = 5001
}

variable "backend_second_port" {
  description = "Port for second backend service"
  type        = number
  default     = 5002
}

variable "frontend_https_port" {
  description = "HTTPS port for frontend"
  type        = number
  default     = 443
}

variable "backend_https_port" {
  description = "HTTPS port for main backend"
  type        = number
  default     = 442
}

variable "backend_second_https_port" {
  description = "HTTPS port for second backend"
  type        = number
  default     = 441
}

variable "task_cpu" {
  description = "CPU units for the main task"
  type        = string
  default     = "1024"
}

variable "task_memory" {
  description = "Memory for the main task"
  type        = string
  default     = "3072"
}

variable "second_backend_cpu" {
  description = "CPU units for the second backend task"
  type        = string
  default     = "512"
}

variable "second_backend_memory" {
  description = "Memory for the second backend task"
  type        = string
  default     = "1024"
}

variable "container_cpu" {
  description = "CPU units for individual containers"
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Memory for individual containers"
  type        = number
  default     = 512
}

# tags.tf file

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default     = {
    Environment = "Test"
    Project     = "ProgramResource"
    ManagedBy   = "Terraform"
  }
}
