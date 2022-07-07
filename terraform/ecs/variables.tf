variable "availability_zones" {
  type        = list(string)
  description = "AWS Availability Zones"
  default = [
    "ap-northeast-1a",
    "ap-northeast-1b",
    "ap-northeast-1c",
    "ap-northeast-1e",
  ]
}

variable "key_pair" {
  description = "AWS EC2 Key Pair Pem"
  default     = "ee-default-keypair"
}

variable "ami" {
  description = "Amazon Linux 2 AMI"
  default     = "ami-0b7546e839d7ace12"
}

variable "instance_type" {
  description = "AWS AMD general purpose instance Type"
  default     = "t3.medium"
}

variable "iam_profile" {
  description = "Name of AWS IAM Profile"
  default     = "ec2ECSRole"
}

variable "asg_min" {
  description = "Min Instances"
  default     = 1
}

variable "asg_max" {
  description = "Max Instances"
  default     = 3
}

variable "asg_desired" {
  description = "AWS Desired capacity for ASG"
  default     = 3
}

variable "docker_img_name" {
  type        = string
  description = "Name of the docker image being deployed"
  default     = "lucmaeda/my-snyk-demo-mvn-goof"
}

variable "docker_img_tag" {
  type        = string
  description = "The docker image TAG being deployed"
  default     = "latest"
}

variable "ecs_desired_count" {
  description = "Number of desired ECS Tasks to deploy"
  default     = 3
}

