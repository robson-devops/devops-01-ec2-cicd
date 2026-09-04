# devops-01-ec2-cicd

Deploy automatizado de uma aplicação containerizada em EC2, com infraestrutura
como código e pipeline de CI/CD — sem nenhum clique no console da AWS e sem
nenhuma porta administrativa exposta.

**Projeto 1 de 5 do portfólio DevOps** · Nível: fundação

![CI/CD](https://github.com/robson-devops/devops-01-ec2-cicd/actions/workflows/ci-cd.yml/badge.svg)

## Stack

`AWS` `Terraform` `Docker` `GitHub Actions` `Python/FastAPI` `CloudWatch` `SSM`

## Arquitetura

Diagrama completo e descrição do fluxo em [`docs/architecture.md`](docs/architecture.md).

```
git push main → build + smoke test → GHCR → SSM RunShellScript → EC2 → CloudWatch
```

## Decisões de Arquitetura

**EC2 sem orquestrador, de propósito.** Este é o primeiro degrau da trilha do
portfólio. O objetivo é demonstrar domínio da camada base — rede, identidade,
compute, observabilidade — antes de abstraí-la. ECS entra no projeto 2 e EKS no
projeto 3, cada um resolvendo uma limitação concreta deixada aqui.

**Deploy via AWS Systems Manager, não SSH.** O runner do GitHub autentica na
AWS e o SSM executa o comando dentro da instância usando a identidade da IAM
Role. Resultado: nenhuma porta 22 aberta, nenhuma chave privada circulando pelo
pipeline. O SSH existe como recurso opcional no Terraform (`ssh_allowed_cidr`),
criado condicionalmente via `count`, e fica desligado por padrão.

**VPC própria em vez da default.** Controle explícito de CIDR, rotas e
associações, em vez de herdar uma configuração que a conta trouxe pronta.

**Regras de security group como recursos individuais**
(`aws_vpc_security_group_ingress_rule`) em vez de blocos `ingress` inline. Blocos
inline substituem todas as regras a cada `apply`, o que causa drift e conflito
quando algo é alterado fora do Terraform.

**IAM Role com duas policies gerenciadas específicas** —
`AmazonSSMManagedInstanceCore` e `CloudWatchAgentServerPolicy` — em vez de uma
policy ampla. A instância só consegue fazer o que o projeto precisa.

**IMDSv2 obrigatório** (`http_tokens = "required"`, hop limit 1). Sem isso, uma
falha de SSRF na aplicação conseguiria ler as credenciais temporárias da Role
pelo metadata service.

**Imagem versionada pelo SHA do commit.** O deploy referencia
`ghcr.io/…:<sha>`, não `latest`. A tag `latest` também é publicada, mas por
conveniência — o que roda em produção é sempre rastreável a um commit.

## Trade-offs Avaliados

| Decisão | Escolhido | Alternativa | Critério |
|---|---|---|---|
| Orquestração | EC2 + Docker | ECS Fargate | Escopo do nível 1 é a camada base; Fargate é o degrau seguinte |
| Acesso administrativo | SSM Session Manager | SSH com key pair | Elimina porta 22 pública e distribuição de chave privada |
| Registro de imagem | GHCR | Amazon ECR | Sem custo adicional e sem acoplar o build a credenciais AWS; ECR entra no projeto 2 |
| IaC | Terraform | CloudFormation | Portabilidade e adoção de mercado; CloudFormation é explorado no projeto 4 |
| Estado do Terraform | Local | S3 + DynamoDB | Ambiente único e sem colaboração não justifica a complexidade; o backend está pronto e comentado em `versions.tf`, e entra no projeto 2 |
| Logs do container | Driver `awslogs` | CloudWatch Agent | Zero configuração dentro da instância; o agent só se justifica com métricas customizadas de SO |
| Autenticação do pipeline na AWS | Access keys em secrets | OIDC | Reconhecidamente inferior — ver Limitações |

## Melhorias Mensuráveis

Medições reais deste projeto, não estimativas:

| Métrica | Resultado |
|---|---|
| Tempo de deploy (commit até aplicação atualizada) | **47s** (build + teste 25s, deploy 15s) |
| Passos manuais no deploy | **0** — apenas `git push` |
| Portas administrativas expostas à internet | **0** |
| Provisionamento completo da infra do zero | `terraform apply` único, reproduzível |
| Cobertura de observabilidade | 1 log group com stream ativo + 2 alarmes em estado `OK` |
| Rastreabilidade | 100% dos deploys amarrados ao SHA do commit |

Validação executada camada por camada na AWS antes de cada etapa seguinte —
procedimento completo e reproduzível em [`docs/validacao-aws.md`](docs/validacao-aws.md).

## Limitações Conhecidas

Cada uma é resolvida em um projeto seguinte da trilha.

- **Instância única, sem alta disponibilidade.** 

    Uma AZ, um host.  
    A janela de indisponibilidade durante o `docker rm`/`docker run` é real.  
    Resolvido no projeto 2 com ECS e deploy sem downtime. 

- **Access keys de longa duração nos secrets do GitHub.**   

  O correto é OIDC com role assumível, sem credencial estática.   
  O `permissions: id-token: write` já está declarado no workflow para essa migração.

- **Sem HTTPS.**  
  A aplicação responde em HTTP na porta 8000. ALB com certificado ACM entra no projeto 2.

- **Estado do Terraform local.**  
  Não suporta trabalho colaborativo nem trava execuções concorrentes.

## Estrutura

```
.
├── app/                    # API FastAPI + Dockerfile
├── terraform/              # VPC, subnet, SG, IAM, EC2, CloudWatch
├── .github/workflows/      # pipeline CI/CD
└── docs/                   # diagrama e procedimento de validação na AWS
└── README.md               # Documentação do projeto
```

## Como executar

### Aplicação local

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r app/requirements.txt
uvicorn main:app --app-dir app --port 8000
curl http://127.0.0.1:8000/health
```

### Infraestrutura

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # opcional: todos os defaults funcionam
terraform init
terraform plan
terraform apply
```

### Pipeline

Configure os secrets do repositório com os valores do `terraform output`:

```bash
gh secret set EC2_INSTANCE_ID --body "$(terraform output -raw instance_id)"
gh secret set AWS_REGION --body "us-east-1"
aws configure get aws_access_key_id     | gh secret set AWS_ACCESS_KEY_ID
aws configure get aws_secret_access_key | gh secret set AWS_SECRET_ACCESS_KEY
```

Um `git push` na `main` dispara build, teste e deploy.

### Encerramento

```bash
cd terraform && terraform destroy
```

## API

| Método | Rota | Descrição |
|---|---|---|
| GET | `/health` | Health check |
| GET | `/tasks` | Lista tarefas |
| POST | `/tasks` | Cria tarefa |
| GET | `/tasks/{id}` | Busca tarefa |
| DELETE | `/tasks/{id}` | Remove tarefa |

A aplicação é deliberadamente mínima e mantém estado em memória — o objeto de
estudo deste projeto é a infraestrutura em volta dela.

## Licença

MIT — ver [LICENSE](LICENSE).
