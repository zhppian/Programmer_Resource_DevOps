terraform {
  backend "s3" {
    bucket         = "terraform-state-program-resource"  # S3 bucket 用于存储 Terraform 状态文件
    key            = "test/state"  # 状态文件路径
    region         = "ap-northeast-3"  # S3 bucket 所在的 AWS 区域
    encrypt        = true  # 启用加密以保护状态文件
  }
}

provider "aws" {
  region = "ap-northeast-3"  # 设置 AWS 区域
}

# ECS Cluster 资源
resource "aws_ecs_cluster" "main" {
  name = "program-resource-tf"  # ECS 集群名称
}

# 获取 ECS 任务执行角色
data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"  # ECS 任务执行角色名称
}

# ECS 任务定义资源
resource "aws_ecs_task_definition" "program_resource" {
  family                   = "program-resource-tf"  # ECS 任务定义系列名称
  network_mode             = "awsvpc"  # 使用 VPC 网络模式
  container_definitions    = jsonencode([
    {
      name      = "frontend-container"  # 前端容器
      image     = "886436941040.dkr.ecr.ap-northeast-3.amazonaws.com/program_resource_frontend:latest"  # 前端容器镜像
      cpu       = 256  # 容器分配的 CPU 单位
      memory    = 512  # 容器分配的内存大小
      essential = true  # 标记此容器为必需
      portMappings = [
        {
          containerPort = 80  # 容器内部的端口
          hostPort      = 80  # 主机端口
        }
      ]
    },
    {
      name      = "backend-container"  # 后端容器
      image     = "886436941040.dkr.ecr.ap-northeast-3.amazonaws.com/program_resource_backend:latest"  # 后端容器镜像
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
  requires_compatibilities = ["FARGATE"]  # 任务定义兼容的运行类型
  cpu                      = "512"  # 整体任务分配的 CPU 单位
  memory                   = "1024"  # 整体任务分配的内存大小
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn  # 使用的 IAM 执行角色
}

# 获取默认 VPC
data "aws_vpc" "default" {
  default = true  # 使用默认 VPC
}

# 获取手动创建的安全组
data "aws_security_group" "http" {
  filter {
    name   = "group-name"  # 筛选条件
    values = ["http-20250105102830995900000001"]  # 手动创建的安全组名称
  }
}

# 获取默认子网
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"  # 筛选条件
    values = [data.aws_vpc.default.id]  # 默认 VPC 的 ID
  }
}

### Load Balancer 配置开始 ###
# 创建 ALB
resource "aws_lb" "main" {
  name               = "program-resource-alb"  # ALB 名称
  internal           = false  # 是否为内部负载均衡器
  load_balancer_type = "application"  # ALB 类型
  security_groups    = [data.aws_security_group.http.id]  # 关联的安全组
  subnets            = data.aws_subnets.default.ids  # 使用的子网
}

# 创建 ALB 的目标组 (Frontend)
resource "aws_lb_target_group" "frontend_tg" {
  name        = "frontend-target-group"  # 目标组名称
  port        = 443  # 更改为 HTTPS 443
  protocol    = "HTTPS"  # 使用 HTTPS 协议
  vpc_id      = data.aws_vpc.default.id  # 目标组所属的 VPC ID
  target_type = "ip"  # 目标类型为 IP
}

# 创建 ALB 的目标组 (Backend)
resource "aws_lb_target_group" "backend_tg" {
  name        = "backend-target-group"  # 目标组名称
  port        = 442  # 更改为 HTTPS 442
  protocol    = "HTTPS"  # 使用 HTTPS 协议
  vpc_id      = data.aws_vpc.default.id  # 目标组所属的 VPC ID
  target_type = "ip"  # 目标类型为 IP
}

# 创建 Listener (Frontend)
resource "aws_lb_listener" "frontend_listener" {
  load_balancer_arn = aws_lb.main.arn  # 关联的 ALB ARN
  port              = 80  # HTTP 80 端口
  protocol          = "HTTP"  # 协议为 HTTP
  default_action {
    type = "redirect"  # 重定向
    redirect {
      port        = "443"  # 重定向到 HTTPS 443
      protocol    = "HTTPS"  # 使用 HTTPS 协议
      status_code = "HTTP_301"  # 重定向状态码
    }
  }
}

# 创建 Listener (Backend)
resource "aws_lb_listener" "backend_listener" {
  load_balancer_arn = aws_lb.main.arn  # 关联的 ALB ARN
  port              = 5001  # HTTP 5001 端口
  protocol          = "HTTP"  # 协议为 HTTP
  default_action {
    type = "redirect"  # 重定向
    redirect {
      port        = "442"  # 重定向到 HTTPS 442
      protocol    = "HTTPS"  # 使用 HTTPS 协议
      status_code = "HTTP_301"  # 重定向状态码
    }
  }
}

# 创建 HTTPS Listener (Frontend)
resource "aws_lb_listener" "frontend_https_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"  # 可根据需要选择 SSL 策略
  certificate_arn   = "arn:aws:acm:ap-northeast-3:886436941040:certificate/03ea08ec-55cb-49f2-81f9-5105b1b75420" # 替换为实际 ACM 证书 ARN

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

# 创建 HTTPS Listener (Backend)
resource "aws_lb_listener" "backend_https_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = 442
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"  # 可根据需要选择 SSL 策略
  certificate_arn   = "arn:aws:acm:ap-northeast-3:886436941040:certificate/03ea08ec-55cb-49f2-81f9-5105b1b75420" # 替换为实际 ACM 证书 ARN

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}

### Load Balancer 配置结束 ###

# 更新 ECS 服务以使用 ALB
resource "aws_ecs_service" "main" {
  name            = "program-resource-tf"  # ECS 服务名称
  cluster         = aws_ecs_cluster.main.id  # 关联的 ECS 集群 ID
  task_definition = aws_ecs_task_definition.program_resource.arn  # 使用的任务定义 ARN
  desired_count   = 1  # 任务数量
  launch_type     = "FARGATE"  # 使用 Fargate 运行类型

  network_configuration {
    subnets          = data.aws_subnets.default.ids  # 使用的子网
    security_groups  = [data.aws_security_group.http.id]  # 使用的安全组
    assign_public_ip = true  # 是否分配公有 IP
  }

  # ALB 和目标组绑定 (Frontend)
  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_tg.arn  # 目标组 ARN
    container_name   = "frontend-container"  # 容器名称
    container_port   = 80  # 容器端口
  }

  # ALB 和目标组绑定 (Backend)
  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tg.arn  # 目标组 ARN
    container_name   = "backend-container"  # 容器名称
    container_port   = 5001  # 容器端口
  }

  depends_on = [
    aws_lb_listener.frontend_listener,  # 确保 ALB 的 Listener 已创建
    aws_lb_listener.backend_listener
  ]
}
