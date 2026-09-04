# Arquitetura — devops-01-ec2-cicd

```mermaid
flowchart TB
    Dev["Desenvolvedor"] -->|git push main| GH

    subgraph Pipeline["GitHub"]
        direction TB
        GH["GitHub Actions"] --> Build["build-and-test<br/>docker build + smoke test"]
        Build --> Deploy["deploy<br/>ssm send-command"]
        Build --> GHCR[("GHCR<br/>tag = SHA")]
    end

    subgraph AWS["AWS us-east-1"]
        direction TB
        SSM["Systems Manager"]
        Role["IAM Role<br/>SSM + CloudWatch"]

        subgraph VPC["VPC"]
            EC2["EC2 t3.micro<br/>subnet publica<br/>IMDSv2 required<br/>EBS gp3 encrypted<br/>Docker + container"]
        end

        CW["CloudWatch<br/>log group + 2 alarmes"]

        SSM -->|RunShellScript| EC2
        Role -.->|instance profile| EC2
        EC2 -->|"awslogs + metricas"| CW
    end

    Deploy --> SSM
    GHCR -.->|docker pull| EC2
    User(["Usuario"]) -->|"GET porta 8000 health"| EC2

    classDef dev fill:#f1f5f9,stroke:#94a3b8,stroke-width:1.5px,color:#0f172a
    classDef ci fill:#dbeafe,stroke:#3b82f6,stroke-width:1.5px,color:#1e3a5f
    classDef registry fill:#ede9fe,stroke:#8b5cf6,stroke-width:1.5px,color:#3b2a6b
    classDef aws fill:#ffedd5,stroke:#f97316,stroke-width:1.5px,color:#7c2d12
    classDef sec fill:#fee2e2,stroke:#ef4444,stroke-width:1.5px,color:#7f1d1d
    classDef obs fill:#dcfce7,stroke:#22c55e,stroke-width:1.5px,color:#14532d

    class Dev,User dev
    class GH,Build,Deploy ci
    class GHCR registry
    class SSM,EC2 aws
    class Role sec
    class CW obs

    style Pipeline fill:#f8fafc,stroke:#cbd5e1,stroke-width:1px,color:#475569
    style AWS fill:#f8fafc,stroke:#cbd5e1,stroke-width:1px,color:#475569
    style VPC fill:#ffffff,stroke:#e2e8f0,stroke-width:1px,color:#64748b
```

## Fluxo

1. `git push` na `main` dispara o workflow.
2. **build-and-test**: builda a imagem, sobe o container no runner e testa
   `/health` e `POST /tasks`. Falhou, o deploy não acontece.
3. Imagem publicada no GHCR com duas tags: o SHA do commit e `latest`.
4. **deploy**: assume credenciais AWS e envia um `RunShellScript` via SSM para
   a instância — `docker pull` da tag do SHA, remove o container antigo e sobe
   o novo com o driver de log `awslogs`.
5. O job faz polling do status do comando SSM e falha se o comando falhar.
6. A instância envia logs e métricas ao CloudWatch.

## Deploy realizado via SSM

Não há porta 22 aberta e nenhuma chave SSH circula pelo pipeline. O runner do
GitHub autentica na AWS e o Systems Manager executa o comando dentro da
instância usando a identidade da IAM Role.  

A superfície de ataque some junto com a porta.