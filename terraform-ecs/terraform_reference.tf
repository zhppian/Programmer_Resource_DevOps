terraform {
  backend "s3" {
    bucket         = "techsum-dl"
    key            = "techsum-terraform-state"  # path to store the state file
    region         = "us-west-1"
    encrypt        = true
  }
}

variable "domain_name" {
  default = "techsum.ai"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_ecs_task_definition" "express_app_task" {
  family                   = "express-app-task2"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2", "FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "arn:aws:iam::111677503276:role/ecsTaskExecutionRole2"

  container_definitions = jsonencode([
    {
      name = "express-app"
      image = "111677503276.dkr.ecr.us-east-1.amazonaws.com/private-techtrend-backend:latest"
      cpu = 0
      portMappings = [
        {
          containerPort = 5001
          hostPort = 5001
          protocol = "tcp"
          name = "4200"
          appProtocol = "http"
        }
      ]
      essential = true
      environment = []
      environmentFiles = []
      mountPoints = []
      volumesFrom = []
      ulimits = []
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group = "true"
          awslogs-group = "/ecs/express-app-task"
          awslogs-region = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
        secretOptions = []
      }
      systemControls = []
    }
  ])

  runtime_platform {
    cpu_architecture       = "X86_64"
    operating_system_family = "LINUX"
  }

  tags = {
    updated_at = timestamp()
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "example-cluster2"
}

# Security Group for ECS Task
resource "aws_security_group" "ecs_task_sg" {
  name        = "ecs-task-sg"
  description = "Allow inbound traffic on port 3000"
  vpc_id      = "vpc-01499388869ea105c"

  ingress {
    from_port   = 80 # Add this line
    to_port     = 80 # Add this line
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 444
    to_port     = 444
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Load Balancer
resource "aws_lb" "app_lb" {
  name               = "app-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_task_sg.id]
  subnets            = ["subnet-05c69e6d0b2031fe7", "subnet-0ebabe854169b2eeb"]

  depends_on = [ 
    aws_security_group.ecs_task_sg
  ]

  enable_deletion_protection = true
}

# Create Target Group
resource "aws_lb_target_group" "app_target_group_3000" {
  name        = "app-target-group-3000"
  port        = 3000 
  protocol    = "HTTP"
  vpc_id      = "vpc-01499388869ea105c"
  target_type = "ip"

  health_check {
    path                = "/health" # Update this to a valid route
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200-299"
  }
}

resource "aws_lb_target_group" "app_target_group_5000" {
  name        = "app-target-group-5000"
  port        = 5001
  protocol    = "HTTP"
  vpc_id      = "vpc-01499388869ea105c"
  target_type = "ip"

  health_check {
    path                = "/health" # Update this to a valid route
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200-299"
  }
}

# Create Listener
resource "aws_lb_listener" "app_lb_listener_3000" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "3000" 
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group_3000.arn
  }

  depends_on = [ 
    aws_lb.app_lb,
    aws_lb_target_group.app_target_group_3000
  ]
}

resource "aws_lb_listener" "app_lb_listener_5000" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "5000" 
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group_5000.arn
  }

  depends_on = [ 
    aws_lb.app_lb,
    aws_lb_target_group.app_target_group_5000
  ]
}

# resource "aws_lb_listener" "app_lb_listener_80" {
#   load_balancer_arn = aws_lb.app_lb.arn
#   port              = "80"
#   protocol          = "HTTP"
# 
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app_target_group_3000.arn
#   }
# 
#   depends_on = [ 
#     aws_lb.app_lb,
#     aws_lb_target_group.app_target_group_3000
#   ]
# }
# Redirect http to https://www.techsum.ai 
resource "aws_lb_listener" "app_lb_listener_80" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      host        = "www.techsum.ai"
      status_code = "HTTP_301"
    }
  }

  depends_on = [ 
    aws_lb.app_lb,
    aws_lb_target_group.app_target_group_3000
  ]
}

# ECS Service
resource "aws_ecs_service" "express_app_service" {
  name            = "express-app-service-new"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.express_app_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds  = 70

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    create_before_destroy = true
  }

  network_configuration {
    subnets         = ["subnet-05c69e6d0b2031fe7", "subnet-0ebabe854169b2eeb"]
    security_groups = [aws_security_group.ecs_task_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_target_group_5000.arn
    container_name   = "express-app"
    container_port   = 5001
  }

  force_new_deployment = true

  depends_on = [
    aws_lb_listener.app_lb_listener_3000,
    aws_iam_role.ecs_task_execution_role,
    aws_ecs_task_definition.express_app_task
  ]

  tags = {
    updated_at = timestamp()
  }
}

variable "frontend_image_tag" {
  description = "Tag for the frontend Docker image"
  default     = "latest"
}

resource "aws_ecs_task_definition" "frontend-task-definition" {
  family                   = "frontend-task-definition"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2", "FARGATE"]
  cpu                      = "1024"
  memory                   = "3072"
  execution_role_arn       = "arn:aws:iam::111677503276:role/ecsTaskExecutionRole2"

  container_definitions = jsonencode([
    {
      name = "frontend-container"
      # image = "111677503276.dkr.ecr.us-east-1.amazonaws.com/private-techtrend-frontend:latest"
      image = "111677503276.dkr.ecr.us-east-1.amazonaws.com/private-techtrend-frontend:${var.frontend_image_tag}"
      cpu = 0
      portMappings = [
        {
          containerPort = 3000 
          hostPort = 3000 
          protocol = "tcp"
          name = "3000"
          appProtocol = "http"
        }
      ]
      essential = true
    #   environment = []
      environment = [
        {
          name = "REACT_APP_BACKEND_URL"
        #   value = "http://${aws_lb.app_lb.dns_name}:5000"
          value = "https://techsum.ai:444"
        }
      ]
      environmentFiles = []
      mountPoints = []
      volumesFrom = []
      ulimits = []
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group = "true"
          awslogs-group = "/ecs/express-app-task"
          awslogs-region = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
        secretOptions = []
      }
      systemControls = []
    }
  ])

  runtime_platform {
    cpu_architecture       = "X86_64"
    operating_system_family = "LINUX"
  }

  tags = {
    updated_at = timestamp()
  }
}

# ECS Service
resource "aws_ecs_service" "frontend-service" {
  name            = "frontend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend-task-definition.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds  = 70

  # This will automatically roll back the deployment if it fails, helping to maintain service availability.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets         = ["subnet-05c69e6d0b2031fe7", "subnet-0ebabe854169b2eeb"]
    security_groups = [aws_security_group.ecs_task_sg.id]
    assign_public_ip = true
  }

  lifecycle {
    create_before_destroy = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_target_group_3000.arn
    container_name   = "frontend-container"
    container_port   = 3000
  }

  depends_on = [
    aws_ecs_service.express_app_service
  ]

  force_new_deployment = true

  tags = {
    updated_at = timestamp()
  }

}

# Add ACM certificate
resource "aws_acm_certificate" "cert" {
  domain_name       = "techsum.ai"
  validation_method = "DNS"

  subject_alternative_names = ["www.techsum.ai"]

  lifecycle {
    create_before_destroy = true
  }
}

# Add HTTPS listeners
resource "aws_lb_listener" "https_443" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group_3000.arn
  }
}

resource "aws_lb_listener" "https_444" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "444"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group_5000.arn
  }
}

# Add Route 53 records
resource "aws_route53_zone" "main" {
  name = "techsum.ai"
}

resource "aws_route53_record" "main" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "techsum.ai"
  type    = "A"

  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.techsum.ai"
  type    = "A"

  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}

# Add DNS validation for ACM certificate 
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn] }

output "express_app_service_deployment_id" {
  value = aws_ecs_service.express_app_service.id
}

output "frontend_service_deployment_id" {
  value = aws_ecs_service.frontend-service.id
}

resource "null_resource" "deploy_backend" {
  triggers = {
    task_definition = aws_ecs_task_definition.express_app_task.arn
  }

  provisioner "local-exec" {
    command = "aws ecs update-service --cluster ${aws_ecs_cluster.main.name} --service ${aws_ecs_service.express_app_service.name} --task-definition ${aws_ecs_task_definition.express_app_task.arn} --force-new-deployment"
  }
}

resource "null_resource" "deploy_frontend" {
  triggers = {
    task_definition = aws_ecs_task_definition.frontend-task-definition.arn
  }

  provisioner "local-exec" {
    command = "aws ecs update-service --cluster ${aws_ecs_cluster.main.name} --service ${aws_ecs_service.frontend-service.name} --task-definition ${aws_ecs_task_definition.frontend-task-definition.arn} --force-new-deployment"
  }

  depends_on = [null_resource.deploy_backend] }
