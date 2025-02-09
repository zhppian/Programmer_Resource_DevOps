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

  health_check {
    path                = "/"
    port                = 80
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }

}

# 创建 ALB 的目标组 (Backend)
resource "aws_lb_target_group" "backend_tg" {
  name        = "backend-target-group"
  port        = 5001
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip" # ECS 使用 IP 模式

  health_check {
    path                = "/"
    port                = 5001
    healthy_threshold   = 2
    unhealthy_threshold = 10
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

# 创建 Listener (Frontend)
resource "aws_lb_listener" "http_redirect" {
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

/*
resource "aws_lb_listener_rule" "backend_path_rule" {
  listener_arn = aws_lb_listener.frontend_https_listener.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}

resource "aws_lb_listener_rule" "frontend_path_rule" {
  listener_arn = aws_lb_listener.frontend_https_listener.arn
  priority     = 20

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}
*/

### Load Balancer 配置结束 ###

### Route53 配置 ###

# 创建托管区域
resource "aws_route53_zone" "program_resource_hub" {
  name = "programresourcehub.com"  # 域名
}

# 创建 A 记录并路由到 ALB
resource "aws_route53_record" "root_record" {
  zone_id = aws_route53_zone.program_resource_hub.zone_id  # 托管区域 ID
  name    = "programresourcehub.com"  # 根域名记录
  type    = "A"  # A 记录
  alias {
    name                   = aws_lb.main.dns_name  # ALB 的 DNS 名称
    zone_id                = aws_lb.main.zone_id  # ALB 的 Zone ID
    evaluate_target_health = true  # 评估目标健康状态
  }
}
### Route53 配置结束 ###

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
