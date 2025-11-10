# Exercice 0 : Configuration de l'environnement de développement

## Objectifs pédagogiques

- Installer Terraform sur une distribution Red Hat / RHEL
- Configurer VS Code avec les extensions nécessaires pour Terraform
- Vérifier que l'installation fonctionne correctement
- Préparer l'environnement pour les exercices suivants

## Contexte

Avant de commencer à travailler avec Terraform, il est essentiel de préparer correctement son environnement de développement. Cet exercice vous guidera à travers l'installation de Terraform et la configuration d'un éditeur de code adapté.

## Prérequis

- Une distribution Linux basée sur Red Hat (RHEL, CentOS, Fedora, Rocky Linux, AlmaLinux)
- Accès administrateur (sudo)
- Connexion Internet

---

## Partie 1 : Installation de Terraform sur Red Hat

💡 Une super bonne idée : mettre les tâches qui suivent dans un playbook Ansible que vous jouerez sur votre VM.

1. **Installer `yum-config-manager` (si nécessaire)** :
```bash
sudo yum install -y yum-utils
```

2. **Ajouter le dépôt officiel HashiCorp** :
```bash
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
```

3. **Installer Terraform** :
```bash
sudo yum -y install terraform
```

4. **Vérifier l'installation** :
```bash
terraform version
```
   - Vous devriez voir la version de Terraform installée (par exemple : `Terraform v1.9.x`)

### Configuration de l'auto-complétion (optionnel mais recommandé)

1. **Pour Bash** :
```bash
terraform -install-autocomplete
```

2. **Recharger votre shell** :
```bash
source ~/.bashrc
```

---

## Partie 2 : Installation et configuration de VS Code

### Étape 1 : Installer VS Code

### Étape 2 : Installer les extensions Terraform essentielles

#### Extension 1 : HashiCorp Terraform (indispensable)

**Installation via la ligne de commande** :
```bash
code --install-extension hashicorp.terraform
```

**Ou via l'interface VS Code** :
1. Ouvrir VS Code
2. Aller dans Extensions (Ctrl+Shift+X)
3. Rechercher "HashiCorp Terraform"
4. Cliquer sur "Install"

**Fonctionnalités** :
- Coloration syntaxique pour les fichiers `.tf`
- Auto-complétion intelligente
- Validation de la syntaxe en temps réel
- Intégration des commandes Terraform
- Formatage automatique du code

#### Extension 2 : Terraform Autocomplete (recommandé)

```bash
code --install-extension erd0s.terraform-autocomplete
```

**Fonctionnalités** :
- Auto-complétion avancée pour les ressources
- Suggestions contextuelles
- Documentation inline

<!-- pas sûr que ce soit utile car ils vont avoir le VSCode sur leur machine, tandis que
 le pilotage d'AWS se fera depuis la VM  -->
<!-- #### Extension 3 : AWS Toolkit

```bash
code --install-extension amazonwebservices.aws-toolkit-vscode
```

**Fonctionnalités** :
- Explorateur de ressources AWS
- Intégration avec AWS CLI
- Visualisation des ressources cloud -->

---

## Partie 3 : Configuration de VS Code pour Terraform

### Créer un fichier de configuration workspace

1. **Créer un dossier pour vos projets Terraform** :
```bash
mkdir -p ~/terraform-projects
cd ~/terraform-projects
```

2. **Ouvrir le dossier dans VS Code** :
```bash
code .
```

3. **Créer les paramètres VS Code** :
   - Appuyez sur `Ctrl+Shift+P`
   - Tapez "Preferences: Open Settings (JSON)"
   - Ajoutez la configuration suivante :

```json
{
  "[terraform]": {
    "editor.defaultFormatter": "hashicorp.terraform",
    "editor.formatOnSave": true,
    "editor.formatOnSaveMode": "file"
  },
  "[terraform-vars]": {
    "editor.defaultFormatter": "hashicorp.terraform",
    "editor.formatOnSave": true
  },
  "terraform.validation.enableEnhancedValidation": true,
  "terraform.experimentalFeatures.validateOnSave": true,
  "terraform.experimentalFeatures.prefillRequiredFields": true,
  "files.associations": {
    "*.tf": "terraform",
    "*.tfvars": "terraform-vars"
  }
}
```

**Explications de la configuration** :
- `formatOnSave: true` : Formate automatiquement le code à la sauvegarde
- `enableEnhancedValidation: true` : Active la validation améliorée (activée par défaut)
- `validateOnSave: true` : Valide la syntaxe à chaque sauvegarde
- `prefillRequiredFields: true` : Pré-remplit les champs obligatoires lors de l'auto-complétion

---

## Résolution de problèmes courants

### Problème : `terraform: command not found`

**Solution** :
```bash
# Vérifier le PATH
echo $PATH

# Si /usr/local/bin n'est pas dans le PATH, l'ajouter
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
source ~/.bashrc
```

### Problème : L'auto-complétion ne fonctionne pas dans VS Code

**Solutions** :
1. Vérifier que l'extension HashiCorp Terraform est bien installée et activée
2. Redémarrer VS Code
3. Vérifier que le serveur de langage est activé dans les paramètres :
```bash
# Ouvrir la palette de commandes (Ctrl+Shift+P)
# Taper "Terraform: Enable Language Server"
```

---

## Pour aller plus loin

- **Documentation officielle** : https://developer.hashicorp.com/terraform/docs
- **Terraform Registry** : https://registry.terraform.io/
- **VS Code Terraform Extension** : https://marketplace.visualstudio.com/items?itemName=HashiCorp.terraform
