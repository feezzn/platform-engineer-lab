# GIT_CLEANUP_GUIDE.md

## 🚨 O Problema

Seu `.terraform/` tem 227MB (binários do Terraform) e GitHub não permite files > 100MB.

Você precisa:
1. Remover `.terraform/` do git (mas MANTER no seu computador)
2. Fazer commit dessa remoção
3. Fazer push

---

## ✅ A Solução (passo a passo)

### Passo 1: Verificar o status

```bash
cd /home/felipe/Laboratorios/platform-engineer-lab

git status
```

Deve mostrar:
```
nothing to commit, working tree clean
```

Ou mostra files modificados. Se tem `.terraform/` listado, é porque está em tracking.

---

### Passo 2: Remover .terraform/ do git (sem deletar do disco)

```bash
git rm --cached -r .terraform/
```

**O que isso faz:**
- Remove `.terraform/` do **git**
- Mas MANTÉM no seu computador (pra você não re-baixar)

---

### Passo 3: Verificar o resultado

```bash
git status

# Deve mostrar algo como:
# Changes to be committed:
#   deleted:    .terraform/...
#   deleted:    .terraform/...
#   (muitos files)
```

---

### Passo 4: Fazer commit

```bash
git commit -m "Remove terraform cache from git tracking

.terraform/ contains provider binaries and is not needed in git.
Developers should run 'terraform init' locally to populate this directory.
Files are ignored in .gitignore but were already tracked."
```

---

### Passo 5: Fazer push

```bash
git push

# Se der erro de "default branch", use:
git push -u origin main
```

---

## 🔧 Se algo der errado

### Erro: "fatal: pathspec '.terraform' did not match any files"

**Significa:** `.terraform/` já foi removido do git há muito tempo.

**Solução:** Ignore esse erro, seu repo está ok.

---

### Erro: "refusing to merge unrelated histories"

```bash
# Isso geralmente não acontece, mas se acontecer:
git pull --allow-unrelated-histories

# Depois:
git push
```

---

### Erro: "Everything up-to-date"

**Significa:** Não tem nada novo pra fazer push.

**Solução:** Seu repo já está sincronizado.

---

## 🎯 Depois do fix, seu .gitignore vai ser:

```
# Terraform
.terraform/
.terraform.lock.hcl
*.tfstate
*.tfstate.*
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc
tfplan
tfplan.json

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db
```

---

## ✅ Checklist final

Depois que você fazer push:

```bash
# 1. Verificar que .terraform/ não está no git
git log --oneline | head -5

# 2. Verificar que está no .gitignore
cat .gitignore | grep -A2 "Terraform"

# 3. Verificar que o tamanho do repo diminuiu
du -sh .git

# 4. Pronto!
echo "✅ Seu repo está limpo!"
```

---

## 🚀 Agora você pode:

1. ✅ Fazer push do AULA_VM_KEY_VAULT.md
2. ✅ Fazer push do DEBUGGING_PRACTICE_TERRAFORM.md
3. ✅ Fazer push do complete-vm-with-keyvault.tf
4. ✅ Seu git estará limpo pra próximos passos
