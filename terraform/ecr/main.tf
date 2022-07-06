terraform {
  backend "remote" {
    organization = "" # Enter the Terraform Cloud Organization here

    workspaces {
      name = "ecr-aws-snyk"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_ecrpublic_repository" "aws_snyk_repo" {
  repository_name = var.ecr_name
}

output "ECR_REPO_ARN" {
  value = aws_ecrpublic_repository.aws_snyk_repo.arn
}

output "ECR_REG_ID" {
  value = aws_ecrpublic_repository.aws_snyk_repo.registry_id
}

output "ECR_NAME" {
  value = aws_ecrpublic_repository.aws_snyk_repo.repository_name
}

output "ECR_URI" {
  value = aws_ecrpublic_repository.aws_snyk_repo.repository_uri
}
