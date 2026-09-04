# Validação manual na AWS — Projeto 1

Esse procedimento deverá ser executado após o `terraform apply`, e antes de construir o pipeline, valida a infraestrutura camada por camada, sem depender do CI/CD.

```bash
INSTANCE_ID=$(terraform output -raw instance_id)
PUBLIC_IP=$(terraform output -raw instance_public_ip)
```

## 1. Credencial ativa

```bash
aws sso login --profile seu-perfil
aws sts get-caller-identity
```

## 2. Provisionamento

```bash
terraform plan
terraform apply
terraform output
```

## 3. Instância registrada no SSM

```bash
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
  --query "InstanceInformationList[0].[InstanceId,PingStatus,PlatformName]" \
  --output text
```

Esperado: `i-xxxxxxxx  Online  Amazon Linux`

## 4. Docker instalado pelo user_data

```bash
CMD_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["docker --version && systemctl is-active docker"]' \
  --query "Command.CommandId" --output text) && sleep 8 && aws ssm get-command-invocation \
  --command-id "$CMD_ID" --instance-id "$INSTANCE_ID" \
  --query "StandardOutputContent" --output text
```

Esperado: versão do Docker + `active`

## 5. Caminho de rede ponta a ponta

Container de teste na porta da aplicação — valida VPC, IGW, route table,
security group e Docker de uma vez.

```bash
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["docker run -d --name teste -p 8000:80 nginx"]' \
  --query "Command.CommandId" --output text

curl -s -o /dev/null -w "%{http_code}\n" "http://$PUBLIC_IP:8000"
```

Esperado: `200`

## 6. Limpeza do teste

```bash
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["docker rm -f teste"]' \
  --query "Command.CommandId" --output text
```

## 7. Alarmes do CloudWatch

```bash
aws cloudwatch describe-alarms \
  --alarm-name-prefix devops-01-ec2-cicd \
  --query "MetricAlarms[].[AlarmName,StateValue]" --output text
```

Esperado: os dois alarmes em `OK` (estado `OK` significa que estão recebendo
métrica e avaliando — `INSUFFICIENT_DATA` indicaria que não chega métrica).

## 8. Logs da aplicação no CloudWatch

Só passa depois que o deploy roda com o driver `awslogs`.

```bash
aws logs describe-log-streams \
  --log-group-name /devops-01-ec2-cicd/app \
  --query "logStreams[].logStreamName" --output text

aws logs get-log-events \
  --log-group-name /devops-01-ec2-cicd/app \
  --log-stream-name app --limit 10 \
  --query "events[].message" --output text
```

Esperado: stream `app` e as linhas de startup do uvicorn. Os `GET /health` de
`127.0.0.1` são o `HEALTHCHECK` do Dockerfile.

## Acesso interativo (opcional)

```bash
aws ssm start-session --target "$INSTANCE_ID" --region us-east-1
```

## Encerramento

```bash
terraform destroy
```
