# Exercice 3 : Variables et fichiers tfvars

## Objectifs pédagogiques

- Comprendre l'utilité des variables dans Terraform
- Apprendre à déclarer et utiliser des variables
- Découvrir les différents types de variables (string, bool, map, etc.)
- Utiliser les fichiers `.tfvars` pour personnaliser les déploiements
- Implémenter des validations de variables
- Rendre le code réutilisable et configurable

## Contexte

Dans l'exercice 2, toutes les valeurs étaient codées en dur dans le fichier `main.tf` (hardcodées). Cela pose plusieurs problèmes :
- Difficile de réutiliser le code pour différents environnements
- Impossible de personnaliser sans modifier le code
- Pas de validation des valeurs saisies
- Code peu maintenable

Les **variables** Terraform permettent de rendre le code paramétrable et réutilisable.

## Instructions

### Partie 1 : Analyser le code existant

1. Dans le dossier `exercise-03/starter/`, vous trouverez le code de l'exercice 2

2. Identifiez toutes les valeurs codées en dur :
   - La région AWS
   - Le préfixe du nom de bucket
   - Les valeurs des tags
   - L'algorithme de chiffrement
   - etc.

3. Listez ces valeurs - ce sont les candidats parfaits pour devenir des variables

### Partie 2 : Créer le fichier variables.tf

1. Créez un fichier `variables.tf` dans le dossier `exercise-03/`

2. Déclarez votre première variable pour la région AWS :
```hcl
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "eu-west-3"
}
```

3. Utilisez cette variable dans `main.tf` :
```hcl
provider "aws" {
  region = var.aws_region  # Au lieu de "eu-west-3"
}
```

4. Testez que ça fonctionne :
```bash
terraform plan
```

### Partie 3 : Ajouter d'autres variables

Créez des variables pour :

1. **bucket_prefix** (string) - Le préfixe du nom de bucket
   - Remplacez `"terraform-training"` par `var.bucket_prefix`

2. **environment** (string) - Le nom de l'environnement
   - Utilisez-le dans les tags

3. **enable_versioning** (bool) - Activer ou non le versioning
   - Valeur par défaut : `true`

4. **enable_encryption** (bool) - Activer ou non le chiffrement
   - Valeur par défaut : `true`

5. **encryption_algorithm** (string) - L'algorithme de chiffrement
   - Valeur par défaut : `"AES256"`
   - Valeurs possibles : `"AES256"` ou `"aws:kms"`

### Partie 4 : Utiliser des ressources conditionnelles

Modifiez les ressources de versioning et encryption pour qu'elles ne soient créées que si les variables correspondantes sont à `true` :

```hcl
resource "aws_s3_bucket_versioning" "my_bucket_versioning" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.my_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

Faites de même pour la ressource d'encryption.

**Explication** :
- `count = var.enable_versioning ? 1 : 0` signifie : "Si enable_versioning est true, crée 1 instance de cette ressource, sinon 0"
- C'est l'opérateur ternaire : `condition ? valeur_si_vrai : valeur_si_faux`

### Partie 5 : Ajouter des validations

Ajoutez une validation à la variable `encryption_algorithm` :

```hcl
variable "encryption_algorithm" {
  description = "Server-side encryption algorithm to use"
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "aws:kms"], var.encryption_algorithm)
    error_message = "Encryption algorithm must be either AES256 or aws:kms"
  }
}
```

Testez la validation en essayant une valeur invalide :
```bash
terraform plan -var="encryption_algorithm=INVALID"
```

### Partie 6 : Variable de type map pour les tags

Ajoutez une variable pour des tags supplémentaires :

```hcl
variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

Utilisez la fonction `merge()` pour combiner les tags par défaut avec les tags personnalisés :

```hcl
resource "aws_s3_bucket" "my_bucket" {
  bucket = "${var.bucket_prefix}-${random_id.bucket_suffix.hex}"

  tags = merge(
    {
      Name        = "${var.bucket_prefix}-${random_id.bucket_suffix.hex}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags  # Tags additionnels fournis par l'utilisateur
  )
}
```

### Partie 7 : Créer un fichier terraform.tfvars

1. Créez un fichier `terraform.tfvars` :
```hcl
aws_region     = "eu-west-3"
bucket_prefix  = "my-awesome-bucket"
environment    = "Development"

enable_versioning = true
enable_encryption = true

tags = {
  Project = "Terraform Training"
  Owner   = "Votre Nom"
}
```

2. Appliquez la configuration :
```bash
terraform init
terraform plan
terraform apply
```

Les valeurs du fichier `.tfvars` sont automatiquement chargées !

### Partie 8 : Créer un fichier outputs.tf (optionnel mais recommandé)

Pour mieux organiser votre code, créez un fichier `outputs.tf` et déplacez-y tous les outputs de `main.tf`.

### Partie 9 : Tester différentes configurations

1. Créez un fichier `production.tfvars` :
```hcl
aws_region        = "eu-west-1"
bucket_prefix     = "prod-bucket"
environment       = "Production"
enable_versioning = true
enable_encryption = true

tags = {
  Project     = "Production App"
  CostCenter  = "Engineering"
  Compliance  = "Required"
}
```

2. Appliquez avec ce fichier spécifique :
```bash
terraform plan -var-file="production.tfvars"
```

3. Créez un fichier `minimal.tfvars` :
```hcl
bucket_prefix     = "minimal-bucket"
enable_versioning = false
enable_encryption = false
```

4. Testez cette configuration minimale :
```bash
terraform plan -var-file="minimal.tfvars"
```

Observez que le versioning et l'encryption ne seront pas créés (count = 0).

### Partie 10 : Variables en ligne de commande

Vous pouvez aussi passer des variables directement en ligne de commande :

```bash
terraform plan \
  -var="bucket_prefix=test-bucket" \
  -var="environment=Test" \
  -var="enable_versioning=false"
```

### Partie 11 : Ordre de priorité des variables

Terraform charge les variables dans cet ordre (du moins prioritaire au plus prioritaire) :

1. Valeurs par défaut dans `variables.tf`
2. Variables d'environnement `TF_VAR_*`
3. Fichier `terraform.tfvars` (automatique)
4. Fichiers `*.auto.tfvars` (automatiques)
5. Option `-var-file` (dans l'ordre de déclaration)
6. Option `-var` (dans l'ordre de déclaration)

Testez cet ordre :

```bash
# 1. Utilisez la valeur par défaut
terraform plan

# 2. Avec une variable d'environnement
export TF_VAR_environment="FromEnv"
terraform plan

# 3. Avec un fichier tfvars (priorité plus haute)
terraform plan -var-file="production.tfvars"

# 4. Avec -var (priorité maximale)
terraform plan -var-file="production.tfvars" -var="environment=Override"
```

## Questions de réflexion

1. **Quand utiliser des variables ?**
   - Quelles valeurs méritent d'être des variables ?
   - Quand est-ce qu'une valeur peut rester codée en dur ?

2. **Valeurs par défaut**
   - Quand faut-il fournir une valeur par défaut ?
   - Quand est-il préférable de rendre une variable obligatoire (pas de default) ?

3. **Organisation des fichiers**
   - Pourquoi séparer `variables.tf`, `main.tf` et `outputs.tf` ?
   - Quels sont les avantages de cette organisation ?

4. **Fichiers .tfvars**
   - Quels fichiers `.tfvars` doit-on commit dans Git ?
   - Lesquels doit-on ajouter au `.gitignore` ? Pourquoi ?

5. **Ressources conditionnelles**
   - Comment feriez-vous pour créer 0, 1 ou plusieurs ressources selon une variable ?
   - Quels sont les cas d'usage du `count` avec des conditions ?

6. **Comparaison avec Ansible**
   - Comment les variables Terraform se comparent-elles aux variables Ansible ?
   - Quelle approche préférez-vous et pourquoi ?

## Problèmes courants

### Erreur : "No value for required variable"
Une variable sans valeur par défaut doit être fournie via `.tfvars`, `-var` ou en ligne de commande.

### Erreur : "Invalid value for variable"
La validation a échoué. Vérifiez que votre valeur respecte les contraintes définies.

### Les variables ne sont pas prises en compte
Vérifiez que vous utilisez `var.nom_variable` et non `nom_variable`.

### Le fichier .tfvars n'est pas chargé
Seul `terraform.tfvars` est chargé automatiquement. Les autres fichiers nécessitent `-var-file=`.

## Pour aller plus loin

- Explorez les types complexes : `list`, `object`, `set`, `tuple`
- Découvrez les [variables sensibles](https://developer.hashicorp.com/terraform/language/values/variables#suppressing-values-in-cli-output)
- Apprenez à utiliser les [locals](https://developer.hashicorp.com/terraform/language/values/locals) (prochain exercice !)
- Explorez les [variable definitions files](https://developer.hashicorp.com/terraform/language/values/variables#variable-definitions-tfvars-files)
