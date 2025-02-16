terraform {
  backend "s3" {
    bucket         = "terraform-state-program-resource"
    key            = "test/state"  # path to store the state file
    region         = "ap-northeast-3"
    encrypt        = true
  }
}

variable "domain_name" {
  default = "programresourcehub.com"
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

data "aws_cloudwatch_log_group" "ecs_logs" {
  name = "ecs"
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
          # hostPort      = 80
        }
      ]
      environment = [
        {
          name  = "VITE_API_BASE_URL"
          value = "https://${aws_lb.main.dns_name}:442"
          # value = "https://domain:5001"
        },
        {
          name  = "VITE_API_SECOND_URL"
          value = "http://${aws_lb.main.dns_name}:441"
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
          # hostPort      = 5001
        }
      ]
    }
    # ,
    # {
    #   name      = "backend-container-5002"
    #   image     = "886436941040.dkr.ecr.ap-northeast-3.amazonaws.com/program_resource_backend_5002:latest"
    #   cpu       = 256
    #   memory    = 512
    #   essential = true
    #   portMappings = [
    #     {
    #       containerPort = 5002  # Internally 5001, but will be routed to 5002 by ALB
    #     }
    #   ]
    # }
  ])

  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "3072"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_ecs_task_definition" "backend_5002" {
  family                   = "program-resource-backend-5002"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "backend-container-5002"
      image     = "886436941040.dkr.ecr.ap-northeast-3.amazonaws.com/program_resource_backend_5002:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 5001  # Internally 5001, but will be routed to 5002 by ALB
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = data.aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = "ap-northeast-3"
          awslogs-stream-prefix = "frontend"
        }
      }
    }
  ])
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

  # health_check {
  #   path                = "/health" # Update this to a valid route
  #   interval            = 30
  #   timeout             = 5
  #   healthy_threshold   = 5
  #   unhealthy_threshold = 5
  #   matcher             = "200-299"
  # }

}

# 创建 ALB 的目标组 (Backend)
resource "aws_lb_target_group" "backend_tg" {
  name        = "backend-target-group"
  port        = 5001
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip" # ECS 使用 IP 模式

  # health_check {
  #   path                = "/health" # Update this to a valid route
  #   interval            = 30
  #   timeout             = 5
  #   healthy_threshold   = 5
  #   unhealthy_threshold = 5
  #   matcher             = "200-299"
  # }
}

resource "aws_lb_target_group" "backend_tg_5002" {
  name        = "backend-target-group-5002"
  port        = 5002
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip" 

  # health_check {
  #   path                = "/health" # Update this to a valid route
  #   interval            = 30
  #   timeout             = 5
  #   healthy_threshold   = 5
  #   unhealthy_threshold = 5
  #   matcher             = "200-299"
  # }
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

  depends_on = [ 
    aws_lb.main,
    aws_lb_target_group.backend_tg
  ]    
}

resource "aws_lb_listener" "backend_listener_5002" {
  load_balancer_arn = aws_lb.main.arn
  port              = 5002
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg_5002.arn
  }

  depends_on = [ 
    aws_lb.main,
    aws_lb_target_group.backend_tg_5002
  ]  
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

resource "aws_lb_listener" "backend_5002_https_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = 441
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"  # 可根据需要选择 SSL 策略
  certificate_arn   = "arn:aws:acm:ap-northeast-3:886436941040:certificate/03ea08ec-55cb-49f2-81f9-5105b1b75420" # 替换为实际 ACM 证书 ARN

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg_5002.arn
  }

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

  depends_on = [ 
    aws_lb.main,
    aws_lb_target_group.frontend_tg
  ] 

}

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

  # load_balancer {
  #   target_group_arn = aws_lb_target_group.backend_tg_5002.arn
  #   container_name   = "backend-container-5002"
  #   container_port   = 5002
  # }

  # 确保 ALB 和目标组的 Listener 在 ECS 服务之前创建
  depends_on = [
    aws_lb_listener.frontend_listener,
    aws_lb_listener.backend_listener,
    aws_lb_listener.backend_https_listener,
    aws_lb_listener.frontend_https_listener
  ]

}

resource "aws_ecs_service" "backend_service_5002" {
  name            = "backend-service-5002"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend_5002.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [data.aws_security_group.http.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tg_5002.arn
    container_name   = "backend-container-5002"
    container_port   = 5001  # Internally still 5001
  }

  depends_on = [
    aws_lb_listener.backend_listener_5002,
    aws_lb_listener.backend_5002_https_listener
    ]
}
