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

data "aws_security_group" "http" {
  filter {
    name   = "group-name"
    values = ["http-20250105102830995900000001"] # 替换为手动创建的安全组名称
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

### Load Balancer 配置开始 ###
# 创建 ALB
resource "aws_lb" "main" {
  name               = "program-resource-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.aws_security_group.http.id]
  subnets            = data.aws_subnets.default.ids
}

# 创建 ALB 的目标组 (Frontend)
resource "aws_lb_target_group" "frontend_tg" {
  name        = "frontend-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip" # ECS 使用 IP 模式
}

# 创建 ALB 的目标组 (Backend)
resource "aws_lb_target_group" "backend_tg" {
  name        = "backend-target-group"
  port        = 5001
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip" # ECS 使用 IP 模式
}

# 创建 Listener (Frontend)
resource "aws_lb_listener" "frontend_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  # 当流量到达 frontend_listener 的 80 端口时，ALB 将其转发到 frontend-target-group 中注册的目标
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

# 创建 Listener (Backend)
resource "aws_lb_listener" "backend_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = 5001
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}
### Load Balancer 配置结束 ###

# 更新 ECS 服务以使用 ALB
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

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_tg.arn
    container_name   = "frontend-container"
    container_port   = 80
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tg.arn
    container_name   = "backend-container"
    container_port   = 5001
  }
  # 确保 ALB 和目标组的 Listener 在 ECS 服务之前创建
  depends_on = [
    aws_lb_listener.frontend_listener,
    aws_lb_listener.backend_listener
  ]
}
