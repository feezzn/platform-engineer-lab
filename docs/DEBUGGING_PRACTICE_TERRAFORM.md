# DEBUGGING_PRACTICE_TERRAFORM.md

## 🚨 Cenários de erro real + como debugar

Deze documento tem exemplos de ERROS reais que podem aparecer em uma entrevista. Para cada erro, vamos pensar em voz alta: "Qual é o erro? Por quê? Como fixo?"

---

## Cenário 1: "Access denied to Key Vault"

### ❌ O erro que você vê

```
Error: creating/updating Key Vault Access Policy: 
tf.Authorization.AuthorizationFailed: Authorization.AuthorizationFailed 
Error can be caused by wrong api-version or credentials.
```

### 🤔 Por quê isso acontece?

Terraform está tentando:
1. Criar o Key Vault ✅ (você consegue)
2. Dar permissão pra você usar o KV ❌ (você NÃO consegue)

**Razão:** Sua conta Azure não tem permissão de "Write" no Key Vault.

### 🔧 Como debugar passo a passo

```bash
# Passo 1: Verificar em qual resource exactamente o erro está
terraform validate
# Deve passar

terraform plan 2>&1 | head -50
# Procura: "azurerm_key_vault_access_policy"
# É ali que está falhando

# Passo 2: Verificar suas permissões NO KEY VAULT
az keyvault show --name platformlabkv123456 --resource-group platformlab-resources

# Passo 3: Ver se a access policy já existe (de tentativas anteriores)
az keyvault access-policy list --name platformlabkv123456 --resource-group platformlab-resources

# Passo 4: Verificar se você é Owner/Contributor
az role assignment list --assignee $(az ad signed-in-user show --query objectId -o tsv)
```

### ✅ Como fixar

**Opção 1: Pedir permissão (se em ambiente real)**
```bash
# Um admin precisa rodar:
az role assignment create \
  --role "Key Vault Contributor" \
  --assignee seu-user-id \
  --scope /subscriptions/seu-subscription
```

**Opção 2: Delete + Recreate (teste local)**
```bash
# Remove do estado terraform
terraform state rm azurerm_key_vault_access_policy.service_principal

# Tenta novamente
terraform apply
```

**Opção 3: Usar account diferente**
```bash
# Logout e login com outra conta
az logout
az login
```

---

## Cenário 2: "Cannot read ~/.ssh/id_rsa.pub"

### ❌ O erro que você vê

```
Error: Invalid value type: root module output "private_key" set to computed value
│ for resource "azurerm_linux_virtual_machine" "test" must not be computed
│
│ on complete-vm-with-keyvault.tf line 104, in resource "azurerm_linux_virtual_machine":
│   104:   public_key = file("~/.ssh/id_rsa.pub")
│
Error: unable to read file at ~/.ssh/id_rsa.pub: open ~/.ssh/id_rsa.pub: 
no such file or directory
```

### 🤔 Por quê isso acontece?

Seu computador não tem uma chave SSH gerada.

### 🔧 Como debugar

```bash
# Passo 1: Verificar se a chave existe
ls -la ~/.ssh/id_rsa.pub

# Se não existir, vai mostrar:
# ls: cannot access ~/.ssh/id_rsa.pub: No such file

# Passo 2: Verificar qual é o seu caminho de home
echo $HOME
# Output: /home/felipe

# Or verificar em qual shell você está
echo $SHELL
# zsh vs bash pode ter diferenças
```

### ✅ Como fixar

```bash
# Criar a chave SSH
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Depois verificar que foi criada
ls -la ~/.ssh/id_rsa*

# Output deve ser:
# -rw------- 1 user group 1700 Dec 20 10:30 .ssh/id_rsa
# -rw-r--r-- 1 user group 1500 Dec 20 10:30 .ssh/id_rsa.pub
```

---

## Cenário 3: "Disk Encryption operation failed"

### ❌ O erro que você vé

```
Error:
  on complete-vm-with-keyvault.tf line 155, in resource "azurerm_virtual_machine_extension":
  155: resource "azurerm_virtual_machine_extension" "disk_encryption" {
     │
     ├─ azurerm_linux_virtual_machine.test: still creating...
     
Error creating Virtual Machine Extension... Disk Encryption operation failed
```

### 🤔 Por quê isso acontece?

Várias possíveis causas:
1. ❌ Access Policy não foi criada (você não tem permissão)
2. ❌ Key Vault Key não foi criada corretamente
3. ❌ Ordem errada de recursos (key_vault_key criou antes da access_policy)

### 🔧 Como debugar

```bash
# Passo 1: Verificar se o KeyVault existe e está acessível
export KV_NAME=$(terraform output key_vault_id | xargs basename)
az keyvault show --name $KV_NAME --resource-group $(terraform output -raw | grep resource_group)

# Passo 2: Verificar se a key foi criada
az keyvault key list --vault-name $KV_NAME

# Se não aparecer "examplekey", significa que falhou

# Passo 3: Ver logs da VM
# Sua VM tem um agente que roda a extensão
# Os logs estão aqui:
cat /var/log/azure/Microsoft.Azure.Security.AzureDiskEncryptionForLinux/*/handler.log

# (Mas você precisa estar logado na VM pra ver isso)
```

### ✅ Como fixar

```bash
# Opção 1: Remover a extensão do estado e tentar novamente
terraform state rm 'azurerm_virtual_machine_extension.disk_encryption'

# Opção 2: Destruir tudo e começar do zero (mais seguro)
terraform destroy

# Opção 3: Verificar a ordem com terraform graph
terraform graph | grep depends_on
```

---

## Cenário 4: "Invalid value for location"

### ❌ O erro que você vê

```
Error: Invalid value for location

│ on complete-vm-with-keyvault.tf line 45, in resource "azurerm_virtual_network":
│   45:   location = azurerm_resource_group.test.location
│
│ expected one of [eastus, westus, centralus, ...]
│ got: ""
```

### 🤔 Por quê isso acontece?

`azurerm_resource_group.test.location` está retornando vazio.

**Razão:** O Resource Group não foi criado ainda (terraform apply não foi rodado).

### 🔧 Como debugar

```bash
# Passo 1: Plan pra ver que a RG vem antes
terraform plan -out=tfplan

# Passo 2: Ver o arquivo tfplan
grep -A5 "azurerm_resource_group" tfplan

# A RG deveria estar marcada para criação ("Plan: 1 to add")

# Passo 3: Check terraform state
terraform state show azurerm_resource_group.test
# Se não existir, terá que rodados apply primeiro
```

### ✅ Como fixar

```bash
# Simples: rodar terraform apply
terraform apply

# Ou se quer ser cuidadoso, roda apply passo a passo
terraform apply -target=azurerm_resource_group.test
```

---

## Cenário 5: "Variable not defined"

### ❌ O erro que você vé

```
Error: Reference to undefined variable

│ on complete-vm-with-keyvault.tf line 150, in resource "azurerm_linux_virtual_machine":
│   150:   size = var.vm_size
│
│ Variable "vm_size" has not been defined.
```

### 🤔 Por quê isso acontece?

Você usou `var.vm_size` mas não declarou essa variável em nenhum lugar.

### 🔧 Como debugar

```bash
# Passo 1: Procurar em qual arquivo a variável seria declarada
grep -r "vm_size" *.tf

# Vai retornar:
# complete-vm-with-keyvault.tf: size = var.vm_size

# Passo 2: Verificar se tem um arquivo variables.tf
ls -la variables.tf

# Se não existir, YOU'RE THE PROBLEM

# Passo 3: Ver quais variáveis foram declaradas
grep "^variable" *.tf
```

### ✅ Como fixar

**Opção 1: Adicionar a declaração**
```hcl
variable "vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}
```

**Opção 2: Remover o uso da variável**
```hcl
# Em vez de:
size = var.vm_size

# Usar:
size = "Standard_D2s_v3"
```

---

## Cenário 6: "Missing required attribute"

### ❌ O erro que você vé

```
Error: Missing required argument

│ on complete-vm-with-keyvault.tf line 105, in resource "azurerm_linux_virtual_machine":
│   105:   admin_ssh_key {
│   106:     username   = "adminuser"
│   107:     public_key = file("~/.ssh/id_rsa.pub")
│   108:   }
│
│ Missing required argument "disabled": false argument is required, 
│ but no definition was found.
```

### 🤔 Por quê?

O resource `azurerm_linux_virtual_machine` mudou na versão do provider.

Nova versão requer `disabled = false` no `admin_ssh_key`.

### ✅ Como fixar

```hcl
admin_ssh_key {
  username   = "adminuser"
  public_key = file("~/.ssh/id_rsa.pub")
  disabled   = false  # Adicione isso
}
```

---

## 🎓 Método geral de debugging que SEMPRE funciona

### Passo 1: Entender o erro

```bash
# Rodas o comando que falhou e presta atenção:

terraform plan

# Procura por:
# - "Error:" (qual é o erro?)
# - "on complete-vm-with-keyvault.tf line 45" (onde está o erro?)
# - "expected one of [...]" (o que é inválido?)
```

### Passo 2: Ler o código nessa linha

```bash
# Abre o arquivo e vai pra linha especificada:
vim complete-vm-with-keyvault.tf +45

# Entende o que aquele código está fazendo
```

### Passo 3: Debugar variáveis

```bash
# Se o erro é "variable not found":
terraform console
# > var.prefx  # Repara que é "prefx" em vez de "prefix"
# > var.location
# > data.azurerm_client_config.current.tenant_id
```

### Passo 4: Simular o recurso isoladamente

```bash
# Se quer testar só o KeyVault:
terraform apply -target=azurerm_key_vault.test

# Se quer deletar só a VM:
terraform destroy -target=azurerm_linux_virtual_machine.test
```

### Passo 5: Ver o estado atual

```bash
# Mostra o que foi criado
terraform state list

# Detalhes de um recurso específico
terraform state show azurerm_key_vault.test

# Compara plan vs estado real
terraform plan -json | jq .
```

---

## 💡 Dicas para a entrevista

1. **Não entre em pânico** - erros são NORMAIS, até esperados

2. **Pense em voz alta**
   ```
   "OK, vejo um erro de 'file not found' na linha 104..."
   "Isso significa que o arquivo ~/.ssh/id_rsa.pub não existe..."
   "Preciso gerar uma chave SSH primeiro..."
   ```

3. **Mostre seu processo de debugging**
   - `terraform validate` (sintaxe correta?)
   - `terraform plan` (o plano faz sentido?)
   - `az` commands (recurso realmente existe no Azure?)
   - Check logs (mensagens de erro mais detalhadas)

4. **Não tente "adivinhar" o fix**
   - Sempre debugar com dados reais
   - Mostrar o comando que você rodou
   - Explicar o resultado

---

## 📝 Exercício: Você pratica agora

Pegue o arquivo `complete-vm-with-keyvault.tf` e:

1. ✅ Rode `terraform validate`
2. ✅ Rode `terraform plan`
3. ✅ Siifra um erro se aparecer (use os passos desse guia)
4. ✅ Rode `terraform destroy` quando terminar

Quando você terminar isso com confiança, você está pronto pra entrevista!
