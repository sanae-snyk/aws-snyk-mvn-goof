terraform {
  required_version = ">= 0.13.5"
  backend "remote" {
    organization = "snyk_demo_pipeline"

    workspaces {
      name = "amd-aws-ecs"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

data "template_file" "user_data" {
  template = file("${path.module}/user_data.sh")

  vars = {
    CLUSTER_NAME = aws_ecs_cluster.app-amd.name
  }
}

data "template_file" "task_definition_json" {
  template = file("${path.module}/task_definition.json")

  vars = {
    DOCKER_IMAGE_NAME = var.docker_img_name,
    DOCKER_IMAGE_TAG  = var.docker_img_tag
  }
}

#  IAMS
data "aws_iam_policy_document" "ecs_agent" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_agent" {
  name               = "ecs-agent"
  assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
}


resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_agent" {
  name = "ecs-agent"
  role = aws_iam_role.ecs_agent.name
}

# AWS Auto Scale Launch Configuration
resource "aws_launch_configuration" "app" {
  name_prefix = "app-amd-"
  security_groups = [
    aws_security_group.app-amd-22.id,
    aws_security_group.app-amd-80.id,
    aws_security_group.app-amd-ELB-HTTP80.id
  ]
  key_name                    = var.key_pair
  image_id                    = var.ami
  instance_type               = var.instance_type
  iam_instance_profile        = aws_iam_instance_profile.ecs_agent.name
  user_data                   = data.template_file.user_data.rendered
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 60
    volume_type           = "standard"
    delete_on_termination = true
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app" {
  name = "app-amd"
  vpc_zone_identifier = [
    aws_subnet.pub_subnet_a.id,
    aws_subnet.pub_subnet_b.id
  ]
  min_size             = var.asg_min
  max_size             = var.asg_max
  desired_capacity     = var.asg_desired
  launch_configuration = aws_launch_configuration.app.name
  target_group_arns    = [aws_alb_target_group.alb.arn]
  tag {
    key                 = "Name"
    value               = "app-amd"
    propagate_at_launch = true
  }
  depends_on = [aws_launch_configuration.app, aws_alb_target_group.alb]
}

# ASG Scaling Policies
resource "aws_autoscaling_policy" "ec2-scale-up" {
  name                   = "app-amd-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

resource "aws_autoscaling_policy" "ec2-scale-down" {
  name                   = "app-amd-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "alarm-high" {
  alarm_name          = "app-amd-alarm-high"
  alarm_description   = "EC2 Scale Up Alarm monitors NetworkOut values"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NetworkOut"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "6000000"
  alarm_actions = [
    aws_autoscaling_policy.ec2-scale-up.arn
  ]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
  depends_on = [
    aws_autoscaling_group.app,
    aws_autoscaling_policy.ec2-scale-up
  ]
}

resource "aws_cloudwatch_metric_alarm" "alarm-low" {
  alarm_name          = "app-amd-alarm-low"
  alarm_description   = "EC2 Scale Down Alarm monitors NetworkOut values"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NetworkOut"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "3000000"
  alarm_actions = [
    aws_autoscaling_policy.ec2-scale-down.arn
  ]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
  depends_on = [
    aws_autoscaling_group.app,
    aws_autoscaling_policy.ec2-scale-down
  ]
}

# AWS SNS Topic
resource "aws_sns_topic" "app-amd-sns" {
  name         = "app-amd-notifications"
  display_name = "app-amd scaling notifications"
}

# AWS ASB Notfication
resource "aws_autoscaling_notification" "asg_notifications" {
  group_names = [
  aws_autoscaling_group.app.name]

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR"
  ]

  topic_arn = aws_sns_topic.app-amd-sns.arn
  depends_on = [
    aws_autoscaling_group.app
  ]
}

# AWS Cloudwatch Log Groups
resource "aws_cloudwatch_log_group" "awslogs-app-amd" {
  name = "awslogs-app-amd"
  tags = {
    team  = "devrel marketing"
    owner = "Snyk TSM APJ"
  }
}

# AWS Application Load Balancer Target Group
resource "aws_alb_target_group" "alb" {
  name                 = "app-amd"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = aws_vpc.vpc.id
  deregistration_delay = 10
  health_check {
    path                = "/"
    healthy_threshold   = 5
    unhealthy_threshold = 10
    interval            = 30
    timeout             = 10
  }

}

#AWS Application Load Balancer
resource "aws_alb" "main" {
  name = "app-amd"
  subnets = [
    aws_subnet.pub_subnet_a.id,
    aws_subnet.pub_subnet_b.id
  ]
  security_groups = [
    aws_security_group.app-amd-ELB-HTTP80.id,
  ]
  tags = {
    team  = "DevRel Marketing",
    owner = "Snyk TSM APJ"
  }
}

#AWS App Load Balancer Listener
resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_alb.main.id
  port              = "80"
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_alb_target_group.alb.id
    type             = "forward"
  }
}

#AWS ECS Task definition
resource "aws_ecs_task_definition" "app-amd" {
  family                = "app-amd"
  container_definitions = data.template_file.task_definition_json.rendered
}

#AWS ECS Cluster
resource "aws_ecs_cluster" "app-amd" {
  name = "app-amd"
}

#AWS ECS Service
resource "aws_ecs_service" "app-amd" {
  name                               = "srv_app-amd"
  cluster                            = aws_ecs_cluster.app-amd.name
  desired_count                      = var.ecs_desired_count
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 100
  task_definition                    = aws_ecs_task_definition.app-amd.arn
  load_balancer {
    target_group_arn = aws_alb_target_group.alb.id
    container_name   = "app-amd"
    container_port   = 5000
  }
  depends_on = [
    aws_alb_listener.front_end
  ]
}
