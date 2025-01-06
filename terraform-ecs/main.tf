terraform {
  backend "s3" {
    bucket         = "terraform-state-program-resource"
    key            = "test/state"  # path to store the state file
    region         = "ap-northeast-3"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-northeast-3"
}

resource "aws_ecs_cluster" "main" {
  name = "program-resource-tf"
}

data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"
}

resource "aws_ecs_task_definition" "program_resource" {
  family                   = "program-resource-tf"
  network_mode             = "awsvpc"
  container_definitions    = jsonencode([
    {
      name      = "frontend-container"
      image     = "886436941040.dkr.ecr.ap-northeast-3.amazonaws.com/program_resource_frontend:latest"
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
      image     = "886436941040.dkr.ecr.ap-northeast-3.amazonaws.com/program_resource_backend:latest"
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

  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
}

data "aws_vpc" "default" {
  default = true
}

# 使用现有手动创建的安全组
data "aws_security_group" "http" {
  filter {
    name   = "group-name"
    values = "http-20250105102830995900000001" # 替换为手动创建的安全组名称
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_ecs_service" "main" {
  name            = "program-resource-tf"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.program_resource.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [data.aws_security_group.http.id]
    assign_public_ip = true
  }
}
