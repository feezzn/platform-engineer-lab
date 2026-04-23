# Platform Engineer Learning Lab

Este repositório foi criado para aprender na prática a construir infraestrutura no Azure usando Terraform, com foco em:

- Azure Resource Group
- Virtual Network (VNet)
- Subnets
- Outputs e variáveis do Terraform

## Objetivo

O objetivo deste projeto é montar uma base de infra simples e funcional no Azure, desenvolvendo o raciocínio de:

- "what" (o que criar)
- "why" (por que criar)
- "how" (como criar)

O foco principal é treinar os conceitos de Azure, Kubernetes e Terraform, alinhados ao tipo de desafio que pode aparecer em entrevistas de Platform Engineer.

## Estrutura do repositório

- `main.tf` - configuração principal do provider e criação dos recursos
- `variables.tf` - definição de variáveis reutilizáveis
- `outputs.tf` - valores exportados pelo Terraform após a aplicação
- `terraform.tfvars` - valores utilizados para executar o plano

## O que foi aprendido

### Terraform
- Configurar o provider `azurerm`
- Criar recursos Azure com `resource` blocks
- Usar variáveis com `var.<nome>`
- Referenciar recursos entre si com `resource_type.name.attribute`
- Definir `outputs` para ver resultados claros após o deploy

### Azure
- Entender que todo recurso precisa de um `Resource Group`
- Criar `Virtual Network` e `Subnet`
- Saber que VNet e Subnet dependem do mesmo `Resource Group`
- Compreender o papel do `Microsoft.Network` no Azure

### Prática
- Executar `terraform init`
- Executar `terraform validate`
- Executar `terraform plan`
- Verificar o que será criado antes do deploy

## Como usar

1. Faça login no Azure:

```bash
az login
az account set --subscription "993a4a88-9c59-4626-83ee-bd3940ea007a"
```

2. Inicialize o Terraform:

```bash
terraform init
```

3. Valide os arquivos:

```bash
terraform validate
```

4. Planeje o deploy:

```bash
terraform plan
```

5. Aplique para criar os recursos:

```bash
terraform apply
```

## Próximos passos

A partir deste ponto inicial, os próximos passos podem ser:

- Adicionar `Storage Account`
- Criar `Azure Container Registry (ACR)`
- Provisionar um `VM`
- Criar um cluster `AKS`
- Adicionar `Key Vault`
- Criar `Network Security Group` e regras de firewall
- Implementar `cluster autoscaler` e `HPA`

## Observações

Este repositório é um laboratório de aprendizado. A ideia é manter um histórico limpo e organizado, com commits e documentação simples para mostrar o raciocínio e a evolução durante a construção da infraestrutura.
