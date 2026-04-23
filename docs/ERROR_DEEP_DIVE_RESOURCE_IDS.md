# ERROR_DEEP_DIVE: Azure Resource ID Parsing

## 🔍 O erro que você viu

```
Error: parsing "azurerm_network_interface.teste.id": 
parsing the NetworkInterface ID: the number of segments didn't match

Expected a NetworkInterface ID that matched (containing 8 segments):
> /subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/example-resource-group/providers/Microsoft.Network/networkInterfaces/networkInterfaceValue

However this value was provided (which was parsed into 0 segments):
> azurerm_network_interface.teste.id
```

## 🧠 O que isso significa?

Azure espera um **Resource ID** em um formato muito específico. Vamos dissecar:

---

## 📋 Anatomia de um Azure Resource ID

### Subnet ID (10 segmentos)

```
/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/example-resource-group/providers/Microsoft.Network/virtualNetworks/myVNet/subnets/mySubnet
│              │                                      │               │                    │        │                 │                    │           │
Seg 0          Seg 1                                  Seg 2           Seg 3                Seg 4    Seg 5             Seg 6                Seg 7       Seg 8
                                                                                                                       Seg 9
```

**Segmentos:**
- **Seg 0:** `/subscriptions` (literal)
- **Seg 1:** Seu Subscription ID (UUID)
- **Seg 2:** `resourceGroups` (literal)
- **Seg 3:** Nome do seu Resource Group
- **Seg 4:** `providers` (literal)
- **Seg 5:** `Microsoft.Network` (provedor)
- **Seg 6:** `virtualNetworks` (literal)
- **Seg 7:** Nome da sua VNet
- **Seg 8:** `subnets` (literal)
- **Seg 9:** Nome da sua Subnet

**Exemplo real:**
```
/subscriptions/993a4a88-9c59-4626-83ee-bd3940ea007a/resourceGroups/platformlab-rg/providers/Microsoft.Network/virtualNetworks/platformlab-vnet/subnets/internal
```

---

### Network Interface ID (8 segmentos)

```
/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/example-resource-group/providers/Microsoft.Network/networkInterfaces/myNIC
│              │                                      │               │                    │        │                 │                    │
Seg 0          Seg 1                                  Seg 2           Seg 3                Seg 4    Seg 5             Seg 6                Seg 7
```

**Segmentos:**
- **Seg 0:** `/subscriptions` (literal)
- **Seg 1:** Seu Subscription ID
- **Seg 2:** `resourceGroups` (literal)
- **Seg 3:** Nome do Resource Group
- **Seg 4:** `providers` (literal)
- **Seg 5:** `Microsoft.Network`
- **Seg 6:** `networkInterfaces` (literal)
- **Seg 7:** Nome da Network Interface

---

## ❌ O erro que você teve

Quando você escreveu:

```hcl
subnet_id = "azurerm_subnet.teste.id"
```

Você passou a **string literal** `"azurerm_subnet.teste.id"` pro Azure.

Azure então tentou parsear isso como um Resource ID:

```
"azurerm_subnet.teste.id"
```

Quantos segmentos tem? **ZERO!** Porque:
- Não tem `/subscriptions` no começo
- Não tem nenhum `/` para separar segmentos
- É só uma string de texto

---

## 🔍 Como Terraform resolve isso

Quando você escreve **SEM aspas**:

```hcl
subnet_id = azurerm_subnet.teste.id
```

Terraform faz isso:

1. ✅ Vê que `azurerm_subnet.teste` é uma referência a um recurso
2. ✅ Procura no estado terraform esse recurso
3. ✅ Extrai o atributo `.id` dele
4. ✅ Passa o valor REAL do ID pro Azure

O ID real é algo como:
```
/subscriptions/993a4a88-9c59-4626-83ee-bd3940ea007a/resourceGroups/platformlab-rg/providers/Microsoft.Network/virtualNetworks/platformlab-vnet/subnets/internal
```

Azure recebe isso e consegue fazer parse (descobre 10 segmentos perfeitamente).

---

## 🎓 Diferentes tipos de IDs

Cada recurso Azure tem uma estrutura diferente. Veja:

### Virtual Network (7 segmentos)

```
/subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.Network/virtualNetworks/{vnetName}
```

### Virtual Machine (8 segmentos)

```
/subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.Compute/virtualMachines/{vmName}
```

### Key Vault (9 segmentos)

```
/subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.KeyVault/vaults/{kv-name}
```

**Lição:** Cada tipo de recurso tem seu próprio número de segmentos! Por isso o erro era tão específico ("expected 8, got 0").

---

## 🛠️ Como você debugaria isso em entrevista

### Passo 1: Entender o erro

```
"OK, erro de parsing... significa que Azure não conseguiu interpretar 
a estrutura do ID que recebi..."
```

### Passo 2: Ler a mensagem de erro

```
"Esperava 8 segmentos, mas recebi 0 segmentos...
Isso é estranho, deve estar recebendo uma string de texto literal."
```

### Passo 3: Procurar no código

```
"Deixa eu procurar onde esse ID vem...
Aqui! Line 42: subnet_id = 'azurerm_subnet.teste.id'
Tem ASPAS! Isso deixa como string de texto, não como referência!"
```

### Passo 4: Fixar

```
"Preciso remover as aspas pra Terraform entender como referência."
```

---

## 💡 Padrão geral para lembrar

### ❌ String literal (aspas)
```hcl
subnet_id = "azurerm_subnet.teste.id"
```
- Azure recebe: `"azurerm_subnet.teste.id"` (texto)
- Azure não consegue fazer parse
- **Erro: 0 segmentos não match com 10 esperados**

### ✅ Referência ao recurso (sem aspas)
```hcl
subnet_id = azurerm_subnet.teste.id
```
- Terraform resolve a referência
- Azure recebe: `/subscriptions/.../subnets/internal` (ID real)
- **Tudo funciona**

---

## 🔧 Teste prático

Para entender melhor, você pode ver o ID real que Terraform gerou:

```bash
# Apply o terraform
terraform apply -lock=false

# Depois vê o ID de um recurso
terraform state show azurerm_subnet.teste

# Output vai ser algo como:
# resource "azurerm_subnet" "teste" {
#   id = "/subscriptions/993a4a88-9c59-4626-83ee-bd3940ea007a/resourceGroups/platformlab-rg/providers/Microsoft.Network/virtualNetworks/platformlab-vnet/subnets/internal"
# }
```

Esse é o ID real que você estava tentando referenciar com aspas!

---

## 📝 Resumo para levar pra entrevista

| Conceito | Detalhe |
|----------|---------|
| **String literal** | `"value"` = texto puro, Azure recebe como está |
| **Referência** | `value` = Terraform resolve pra um valor real |
| **Azure ID** | Padrão `/subscriptions/{id}/resourceGroups/{rg}/providers/{provider}/{type}/{name}` |
| **Segmentos** | Cada `/` separa um segmento; Azure espera número específico por tipo |
| **Debug** | "Recebi 0 segmentos" = provavelmente string literal em aspas |

---

## 🚀 Próximo passo

Quando rodar `terraform apply -lock=false`, você vai ver criados:
- ✅ Resource Group
- ✅ Virtual Network  
- ✅ Subnet (com ID de 10 segmentos!)
- ✅ Network Interface (com ID de 8 segmentos!)
- ✅ Linux VM

Aí você pode fazer `terraform state show` pra ver os IDs reais!
