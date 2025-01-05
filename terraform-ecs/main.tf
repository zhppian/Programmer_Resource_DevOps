provider "aws" {
  region = "ap-northeast-3"
}

resource "aws_ecs_service" "main" {
  name            = "program-resource-frontend-tf"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = 1
  
  lifecycle {
    ignore_changes = [task_definition]
  }

  # 自动更新配置，可以通过触发更新来实现
  depends_on = [
    aws_ecr_repository.main
  ]
}

