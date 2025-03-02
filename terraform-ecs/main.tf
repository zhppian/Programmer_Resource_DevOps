# Define terraform backend configuration to store state in S3
terraform {
  backend "s3" {
    bucket         = "terraform-state-program-resource"
    key            = "test/state"  # path to store the state file
    region         = "ap-northeast-3"
    encrypt        = true
  }
}

# Define AWS provider and region
provider "aws" {
  region = var.region
}

# Create IAM role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role-var"
  tags = var.common_tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policy to the IAM role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3_full_access" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Create ECS cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-tf"
  tags = var.common_tags
}

# Reference existing CloudWatch log group for ECS logs
data "aws_cloudwatch_log_group" "ecs_logs" {
  name = "ecs"
}

# Define ECS task definition for main application (frontend + backend)
resource "aws_ecs_task_definition" "program_resource" {
  family                   = "${var.app_name}-tf"
  network_mode             = "awsvpc"
  container_definitions    = jsonencode([
    {
      name      = "frontend-container"
      image     = "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.app_name}-frontend:latest"
      cpu       = var.container_cpu
      memory    = var.container_memory
      essential = true
      portMappings = [
        {
          containerPort = var.frontend_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = data.aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "frontend"
        }
      }
      environment = [
        {
          name  = "VITE_API_BASE_URL"
          value = "https://${var.domain_name}:${var.backend_https_port}"
        },
        {
          name  = "VITE_API_SECOND_URL"
          value = "https://${var.domain_name}:${var.backend_second_https_port}"
        }
      ]
    },
    {
      name      = "backend-container"
      image     = "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.app_name}-backend:latest"
      cpu       = var.container_cpu
      memory    = var.container_memory
      essential = true
      portMappings = [
        {
          containerPort = var.backend_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = data.aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "backend"
        }
      }      
    }
  ])

  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  tags                     = var.common_tags
}

# Define separate ECS task definition for backend port 5002
resource "aws_ecs_task_definition" "backend_5002" {
  family                   = "${var.app_name}-backend-5002"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.second_backend_cpu
  memory                   = var.second_backend_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  tags                     = var.common_tags

  container_definitions = jsonencode([
    {
      name      = "backend-container-5002"
      image     = "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.app_name}-backend-5002:latest"
      cpu       = var.container_cpu
      memory    = var.container_memory
      essential = true
      portMappings = [
        {
          containerPort = var.backend_port  # Internally 5001, but will be routed to 5002 by ALB
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = data.aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "backend-jobmarket"
        }
      }
    }
  ])
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Create security group for HTTP traffic
resource "aws_security_group" "http" {
  name_prefix = "http-"
  description = "Allow HTTP traffic"
  vpc_id      = data.aws_vpc.default.id
  tags        = var.common_tags

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = var.backend_port
    to_port     = var.backend_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = var.frontend_port
    to_port     = var.frontend_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = var.backend_second_port
    to_port     = var.backend_second_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = var.frontend_https_port
    to_port     = var.frontend_https_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = var.backend_https_port
    to_port     = var.backend_https_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = var.backend_second_https_port
    to_port     = var.backend_second_https_port
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

# Get default subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

### Load Balancer Configuration Start ###
# Create Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.http.id]
  subnets            = data.aws_subnets.default.ids
  tags               = var.common_tags
}

# Create frontend target group
resource "aws_lb_target_group" "frontend_tg" {
  name        = "frontend-target-group"
  port        = var.frontend_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip" # ECS uses IP mode
  tags        = var.common_tags

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-499"  # Accept a wider range of success codes
  }
}

# Create backend target group for port 5001
resource "aws_lb_target_group" "backend_tg" {
  name        = "backend-target-group"
  port        = var.backend_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip" # ECS uses IP mode
  tags        = var.common_tags

  health_check {
    path                = "/health"  # Assumes a health endpoint exists
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-499"  # Accept a wider range of success codes
  }
}

# Create backend target group for port 5002
resource "aws_lb_target_group" "backend_tg_5002" {
  name        = "backend-target-group-5002"
  port        = var.backend_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"
  tags        = var.common_tags

  health_check {
    path                = "/health"  # Assumes a health endpoint exists
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-499"  # Accept a wider range of success codes
  }
}

# Create HTTP listener for backend port 5001
resource "aws_lb_listener" "backend_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.backend_port
  protocol          = "HTTP"
  tags              = var.common_tags

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }

  depends_on = [ 
    aws_lb.main,
    aws_lb_target_group.backend_tg
  ]    
}

# Create HTTP listener for backend port 5002
resource "aws_lb_listener" "backend_listener_5002" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.backend_second_port
  protocol          = "HTTP"
  tags              = var.common_tags

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg_5002.arn
  }

  depends_on = [ 
    aws_lb.main,
    aws_lb_target_group.backend_tg_5002
  ]  
}

# Create HTTP listener for frontend port 5173
resource "aws_lb_listener" "frontend_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.frontend_port
  protocol          = "HTTP"
  tags              = var.common_tags

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }

  depends_on = [ 
    aws_lb.main,
    aws_lb_target_group.frontend_tg
  ]  
}

# Create HTTPS listener for frontend
resource "aws_lb_listener" "frontend_https_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.frontend_https_port
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn
  tags              = var.common_tags

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

# Create HTTPS listener for backend port 5001
resource "aws_lb_listener" "backend_https_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.backend_https_port
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn
  tags              = var.common_tags

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}

# Create HTTPS listener for backend port 5002
resource "aws_lb_listener" "backend_5002_https_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.backend_second_https_port
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn
  tags              = var.common_tags

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg_5002.arn
  }
}

# Create HTTP to HTTPS redirect listener
resource "aws_lb_listener" "http_to_https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  tags              = var.common_tags
  
  default_action {
    type = "redirect"
    redirect {
      port        = var.frontend_https_port
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  depends_on = [ 
    aws_lb.main,
    aws_lb_target_group.frontend_tg
  ] 
}
### Load Balancer Configuration End ###

### Route53 Configuration ###

# Create hosted zone
resource "aws_route53_zone" "program_resource_hub" {
  name = var.domain_name
  tags = var.common_tags
}

# Create A record pointing to ALB
resource "aws_route53_record" "root_record" {
  zone_id = aws_route53_zone.program_resource_hub.zone_id
  name    = var.domain_name
  type    = "A"
  
  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
### Route53 Configuration End ###

# Create ECS service for main application
resource "aws_ecs_service" "main" {
  name            = "${var.app_name}-tf"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.program_resource.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  tags            = var.common_tags

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.http.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_tg.arn
    container_name   = "frontend-container"
    container_port   = var.frontend_port
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tg.arn
    container_name   = "backend-container"
    container_port   = var.backend_port
  }

  # Ensure ALB and target group listeners are created before ECS service
  depends_on = [
    aws_lb_listener.frontend_listener,
    aws_lb_listener.http_to_https,
    aws_lb_listener.backend_listener,
    aws_lb_listener.backend_https_listener,
    aws_lb_listener.frontend_https_listener
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# Create separate ECS service for backend port 5002
resource "aws_ecs_service" "backend_service_5002" {
  name            = "backend-service-5002"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend_5002.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  tags            = var.common_tags

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.http.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tg_5002.arn
    container_name   = "backend-container-5002"
    container_port   = var.backend_port  # Internally still 5001
  }

  depends_on = [
    aws_lb_listener.backend_listener_5002,
    aws_lb_listener.backend_5002_https_listener
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# Outputs
output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "domain_name" {
  description = "The domain name of the application"
  value       = var.domain_name
}

output "nameservers" {
  description = "The nameservers for the Route53 zone"
  value       = aws_route53_zone.program_resource_hub.name_servers
}