variable "aws_region" {
  description = "Região AWS onde os recursos serão provisionados"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto usado para taguear os recursos provisionados"
  type        = string
  default     = "devops-01-ec2-cicd"
}

variable "vpc_cidr" {
  description = "CIDR block da VPC onde os recursos serão provisionados"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block da sub-rede pública onde os recursos serão provisionados"
  type        = string
  default     = "10.20.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block da sub-rede privada onde os recursos serão provisionados"
  type        = string
  default     = "10.20.2.0/24"
}

variable "availability_zone" {
  description = "Zona de disponibilidade onde os recursos serão provisionados"
  type        = string
  default     = "us-east-1a"
}

variable "instance_type" {
  description = "Tipo de instância EC2 a ser provisionada"
  type        = string
  default     = "t2.micro"
}

variable "app_port" {
  description = "Porta da aplicação"
  type        = number
  default     = 8000
}

variable "ssh_allow_cidr" {
  description = "CIDR block para permitir acesso SSH à instância EC2"
  type        = string
  default     = null

  validation {
    condition     = var.ssh_allow_cidr == null ? true : can(cidrhost(var.ssh_allow_cidr, 0))
    error_message = "O valor de ssh_allow_cidr deve ser um CIDR válido ou 'null'."
  }
}

variable "key_pair_name" {
  description = "Nome do par de chaves SSH para acessar a instância EC2"
  type        = string
  default     = null # Para acesso via SSM.
}

variable "log_retention_days" {
  description = "Número de dias para retenção dos logs do CloudWatch"
  type        = number
  default     = 14

}