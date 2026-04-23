# Aula: VM com Key Vault e Disk Encryption

Este arquivo explica o código Terraform que combina VM, Key Vault e criptografia de disco.

## 🎯 O que este código faz

Cria uma infraestrutura completa com:
- **Resource Group** (container lógico)
- **Key Vault** (armazenar chaves/secrets)
- **Virtual Network + Subnet** (rede)
- **Network Interface** (placa de rede da VM)
- **Linux Virtual Machine** (o servidor)
- **Disk Encryption** (criptografia de disco usando a chave do Key Vault)

---

## 📝 Entendendo cada parte

### 1) Provider com features

```hcl
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy       = false
      purge_soft_deleted_keys_on_destroy = false
    }
  }
}
```

**O que é:**
- Você está dizendo ao Terraform como se comportar em certos cenários
- `purge_soft_delete_on_destroy = false` = quando deletar o Key Vault, não apagar completamente (soft delete, recuperável)

**Por quê:**
- Key Vaults com dados importantes não devem ser deletados permanentemente por acidente
- Isso te protege de perder dados críticos

---

### 2) Data source

```hcl
data "azurerm_client_config" "current" {}
```

**O que é:**
- É uma "informação que você LÊ do Azure", não cria
- "client config" = informações da sua conta Azure

**Por quê:**
- Você precisa de seu `tenant_id` (seu Azure AD)
- Você precisa de seu `object_id` (seu ID de usuário no Azure)
- Em vez de hardcodar esses valores, você lê do Azure

**Como usar depois:**
```hcl
tenant_id = data.azurerm_client_config.current.tenant_id
object_id = data.azurerm_client_config.current.object_id
```

---

### 3) Resource Group

```hcl
resource "azurerm_resource_group" "test" {
  name     = "${var.prefix}-resources"
  location = var.location
}
```

**O que é:**
- Container lógico onde TUDO fica dentro

**Por quê:**
- Todo recurso Azure precisa estar em um RG
- O RG agrupa recursos e simplifica billing/permissões

---

### 4) Key Vault

```hcl
resource "azurerm_key_vault" "test" {
  name                        = "${var.prefix}kv"
  location                    = azurerm_resource_group.test.location
  resource_group_name         = azurerm_resource_group.test.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "premium"
  enabled_for_disk_encryption = true
  purge_protection_enabled    = true
}
```

**O que é:**
- Um "cofre seguro" para guardar chaves criptográficas, senhas, secrets

**Por quê:**
- Você não quer deixar chaves em texto plano no código
- Key Vault é onde Azure recomenda guardar isso

**Propriedades importantes:**
- `enabled_for_disk_encryption = true` = permite usar chaves do KV pra criptografar discos
- `purge_protection_enabled = true` = não permite deletar completamente (segurança extra)
- `sku_name = "premium"` = bem mais caro, mas com features melhores

---

### 5) Access Policy

```hcl
resource "azurerm_key_vault_access_policy" "service-principal" {
  key_vault_id = azurerm_key_vault.test.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Create",
    "Delete",
    "Get",
    "Update",
  ]

  secret_permissions = [
    "Get",
    "Delete",
    "Set",
  ]
}
```

**O que é:**
- Define QUEM pode fazer O QUÊ no Key Vault
- É o sistema de permissões (RBAC) do Key Vault

**Por quê:**
- Mesmo dentro do Key Vault, nem todo mundo pode fazer tudo
- Você define: "Esse usuário pode apenas LER" ou "Esse pode CRIAR/DELETE"

**Importante:**
- `object_id = data.azurerm_client_config.current.object_id` = você mesmo (seu usuário)
- Você precisa de permissões para criar as chaves

---

### 6) Key Vault Key

```hcl
resource "azurerm_key_vault_key" "test" {
  name         = "examplekey"
  key_vault_id = azurerm_key_vault.test.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  depends_on = [
    azurerm_key_vault_access_policy.service-principal
  ]
}
```

**O que é:**
- Uma chave criptográfica RSA (2048 bits)
- Será usada para criptografar o disco da VM

**Por quê:**
- RSA é um padrão de criptografia forte
- 2048 bits é tamanho seguro

**`depends_on`:**
- Garante que a access policy seja criada ANTES da chave
- Sem isso, pode falhar porque você não teria permissão

---

### 7) Virtual Network + Subnet

```hcl
resource "azurerm_virtual_network" "test" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
}

resource "azurerm_subnet" "test" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.test.name
  virtual_network_name = azurerm_virtual_network.test.name
  address_prefixes     = ["10.0.2.0/24"]
}
```

**O que é:**
- VNet = rede virtual (todo seu ambiente fica aqui)
- Subnet = sub-rede dentro da VNet

**Por quê:**
- A VM precisa estar em uma rede
- Precisa de um IP (que vem da subnet)

---

### 8) Network Interface (NIC)

```hcl
resource "azurerm_network_interface" "test" {
  name                = "${var.prefix}-nic"
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.test.id
    private_ip_address_allocation = "Dynamic"
  }
}
```

**O que é:**
- É a "placa de rede" da VM
- Conecta a VM à subnet

**Por quê:**
- VMs não se conectam diretamente à subnet
- Elas se conectam via NIC (network interface)

**`private_ip_address_allocation = "Dynamic"`:**
- Azure atribui um IP privado automaticamente (10.x.x.x)

---

### 9) Linux Virtual Machine

```hcl
resource "azurerm_linux_virtual_machine" "test" {
  name                = "${var.prefix}-vm"
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location
  size                = "Standard_D2s_v3"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.test.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}
```

**O que é:**
- A VM propriamente dita

**Propriedades importantes:**
- `size = "Standard_D2s_v3"` = tamanho (2 CPUs, 8GB RAM)
- `admin_ssh_key` = permite fazer login via SSH usando sua chave pública
- `source_image_reference` = qual imagem usar (Ubuntu 22.04 LTS)
- `os_disk` = tipo de armazenamento do sistema operacional

**Por quê `file("~/.ssh/id_rsa.pub")`:**
- Pega sua chave SSH pública do seu computador
- Bota na VM pra você poder fazer SSH

---

### 10) VM Extension (Disk Encryption)

```hcl
resource "azurerm_virtual_machine_extension" "test" {
  name                       = "AzureDiskEncryptionForLinux"
  publisher                  = "Microsoft.Azure.Security"
  type                       = "AzureDiskEncryptionForLinux"
  type_handler_version       = "1.1"
  auto_upgrade_minor_version = false
  virtual_machine_id         = azurerm_linux_virtual_machine.test.id

  settings = <<SETTINGS
{
  "EncryptionOperation": "EnableEncryption",
  "KeyEncryptionAlgorithm": "RSA-OAEP",
  "KeyVaultURL": "${azurerm_key_vault.test.vault_uri}",
  "KeyVaultResourceId": "${azurerm_key_vault.test.id}",
  "KeyEncryptionKeyURL": "${azurerm_key_vault_key.test.id}",
  "KekVaultResourceId": "${azurerm_key_vault.test.id}",
  "VolumeType": "All"
}
SETTINGS
}
```

**O que é:**
- Uma "extension" é um script/agente que roda na VM
- Essa extension criptografa o disco usando a chave do Key Vault

**Por quê:**
- Disco criptografado = seus dados estão protegidos
- Se alguém roubar o disco físico, não consegue ler os dados

**O que acontece:**
- A extension pega a chave do Key Vault
- Usa essa chave pra criptografar o disco da VM
- Depois, quando a VM iniciar, precisa dessa chave pra descriptografar

---

## 🐛 Possíveis erros e como debugar

### Erro 1: "Access denied to Key Vault"

```
Error: creating/updating Key Vault Access Policy: 
Authorization.AuthorizationFailed
```

**Por quê:**
- Você não tem permissão pra criar policies no Key Vault

**Como fixar:**
- Você precisa ser Owner ou Contributor na subscription
- Peça pro admin dar essas permissões

### Erro 2: "Cannot find SSH key"

```
Error: source_image_reference.* : invalid or missing key
```

**Por quê:**
- Seu arquivo `~/.ssh/id_rsa.pub` não existe

**Como fixar:**
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

### Erro 3: "Disk Encryption failed"

```
Error: Disk Encryption operation failed
```

**Por quê:**
- Access policy não foi criada corretamente
- Key não foi criada

**Como debugar:**
```bash
terraform plan -input=false

# Se falhar, vê qual resource falhou
# Geralmente é a access_policy ou key

# Verifique:
az keyvault show --name <seu-kv> --resource-group <seu-rg>
az keyvault key list --vault-name <seu-kv>
```

---

## 🎓 Padrões importantes

### 1) Usar data sources

Em vez de hardcodar seu tenant_id:
```hcl
❌ tenant_id = "123456789"
✅ tenant_id = data.azurerm_client_config.current.tenant_id
```

### 2) Usar depends_on para ordenação

```hcl
depends_on = [
  azurerm_key_vault_access_policy.service-principal
]
```

Garante que a policy seja criada antes da key.

### 3) Usar variables

```hcl
❌ name = "meuprefix-vm"
✅ name = "${var.prefix}-vm"
```

Assim você pode reutilizar o código em vários ambientes.

### 4) Reference entre recursos

```hcl
❌ key_vault_id = "/subscriptions/.../keyvaults/..."
✅ key_vault_id = azurerm_key_vault.test.id
```

Terraform cuida das dependências automaticamente.

---

## 📋 Checklist pra você fazer agora

1. ✅ Entender por que cada recurso existe
2. ✅ Entender a ordem (RG → KV → Access Policy → Key → VM)
3. ✅ Saber usar `data.azurerm_client_config.current`
4. ✅ Saber debugar erros de permissão
5. ✅ Saber ler o plano e entender o que vai ser criado

---

## 💡 Dica para a entrevista

Eles vão perguntar coisas como:

- "Por que usar Key Vault?"
- "Por que essa ordem de recursos?"
- "O que é uma VM Extension?"
- "Como você debugaria se a criptografia falhasse?"

**Responda:**
- Com calma
- Pensando em voz alta: "Primeiro preciso de X, porque Y, depois Z..."
- Mostrando que você entendeu o "why" de cada passo
