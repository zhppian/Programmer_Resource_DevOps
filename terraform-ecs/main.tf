provider "aws" {
  region = "ap-northeast-3"
}

# 定义 ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "program-resource-tf"
}

# 使用既存 IAM Role
data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"
}

# 定义 ECS Task Definition
resource "aws_ecs_task_definition" "program_resource" {
  family                   = "program-resource-tf"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "frontend-container"
      image     = "886436941040.dkr.ecr.ap-northeast-3.amazonaws.com/program_resource_frontend:latest" # 确保镜像最新
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    },
    {
      name      = "backend-container"
      image     = "886436941040.dkr.ecr.ap-northeast-3.amazonaws.com/program_resource_backend:latest" # 确保镜像最新
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 5001
          hostPort      = 5001
        }
      ]
    }
  ])
}

# 加载默认 VPC 和子网
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 定义安全组
resource "aws_security_group" "http" {
  name_prefix = "http-"
  description = "Allow HTTP traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 定义 ECS 服务
resource "aws_ecs_service" "main" {
  name            = "program-resource-frontend-tf"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.program_resource.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.http.id]
    assign_public_ip = true
  }

  # 防止不必要的销毁和重建
  lifecycle {
    ignore_changes = [
      desired_count, # 忽略实例数量的变化
    ]
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
}
