variable "image_name" {
  type        = string
  description = "Name of the docker image being deployed"
  default     = "docker.io/lucmaeda/my-snyk-demo-mvn-goof"
}

variable "image_tag" {
  type        = string
  description = "The docker image TAG being deployed"
  default     = "latest"
}