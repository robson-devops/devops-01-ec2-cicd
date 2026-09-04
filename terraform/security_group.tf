resource "aws_security_group" "app" {
  name        = "${var.project_name}-sg"
  description = "Tráfego da aplicação e acesso administrativo controlado"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  security_group_id = aws_security_group.app.id
  description       = "Porta da aplicacao"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = var.app_port
  to_port           = var.app_port
  ip_protocol       = "tcp"

  tags = {
    Name = "${var.project_name}-ingress-app"
  }
}

# O acesso à instância é via SSM Session Manager.
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  count = var.ssh_allow_cidr == null ? 0 : 1

  security_group_id = aws_security_group.app.id
  description       = "SSH restrito para depuração."
  cidr_ipv4         = var.ssh_allow_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"

  tags = {
    Name = "${var.project_name}-ingress-ssh"
  }
}

# Necessária para pull da imagem no GHCR, atualização de
# pacotes e comunicação do agente SSM/CloudWatch com os endpoints da AWS.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.app.id
  description       = "Saida liberada"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = {
    Name = "${var.project_name}-egress-all"
  }
}