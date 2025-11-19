# Exercice 4 : Utiliser les locals pour éviter les redondances

## Objectifs pédagogiques

- Comprendre la différence entre variables et locals
- Découvrir les cas d'usage des locals
- Apprendre à calculer des valeurs dérivées
- Éviter la répétition de code (principe DRY - Don't Repeat Yourself)
- Améliorer la maintenabilité du code Terraform

## Contexte

Dans l'exercice 3, vous avez appris à utiliser les variables pour paramétrer votre code. Cependant, certaines valeurs sont :
- **Répétées plusieurs fois** (comme le nom du bucket)
- **Calculées à partir de variables** (comme la combinaison de plusieurs valeurs)
- **Utilisées en interne uniquement** (pas besoin d'être configurables)

Les **locals** (valeurs locales) permettent de résoudre ces problèmes en définissant des valeurs calculées et réutilisables.

## Différence entre variables et locals

| Aspect          | Variables (`var.*`)                 | Locals (`local.*`)                    |
| --------------- | ----------------------------------- | ------------------------------------- |
| **Source**      | Définies par l'utilisateur (inputs) | Calculées dans le code                |
| **Modifiables** | Oui (via tfvars, -var, etc.)        | Non (fixes après calcul)              |
| **Usage**       | Configuration externe               | Logique interne                       |
| **Exemple**     | Région AWS, nom de projet           | Nom complet du bucket, tags fusionnés |

**Règle simple** :
- Les **variables** sont des **inputs** (ce que l'utilisateur fournit)
- Les **locals** sont des **calculs** (ce que Terraform déduit)

## Instructions

### Partie 1 : Identifier les redondances

1. Dans le dossier `exercise-04/starter/`, examinez votre code de l'exercice 3

2. Identifiez les valeurs répétées. Par exemple :
   - Le nom du bucket : `"${var.bucket_prefix}-${random_id.bucket_suffix.hex}"`
   - Les tags communs qui apparaissent potentiellement à plusieurs endroits
   - Les valeurs calculées à partir de variables

3. Listez toutes ces redondances - ce sont des candidats parfaits pour devenir des locals

### Partie 2 : Créer le fichier locals.tf

1. Créez un fichier `locals.tf` dans le dossier `exercise-04/`

2. Commencez par créer un local pour le nom du bucket :

```hcl
locals {
  bucket_name = "${var.bucket_prefix}-${random_id.bucket_suffix.hex}"
}
```

3. Utilisez ce local dans `main.tf` :

```hcl
resource "aws_s3_bucket" "my_bucket" {
  bucket = local.bucket_name  # Au lieu de répéter la concaténation

  tags = {
    Name        = local.bucket_name  # Réutilisation du même local
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

4. Testez que ça fonctionne :
```bash
terraform plan
```

### Partie 3 : Créer des locals pour les tags

1. Créez un local pour les tags communs :

```hcl
locals {
  bucket_name = "${var.bucket_prefix}-${random_id.bucket_suffix.hex}"

  common_tags = {
    Name        = local.bucket_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

2. Avant d'aller plus loin, ajoutez des variables dans `variables.tf` pour le projet et le propriétaire :

```hcl
variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "Terraform Training"
}

variable "owner" {
  description = "Owner name for tagging"
  type        = string
  default     = "Student"
}
```

3. Enrichissez vos `common_tags` :

```hcl
locals {
  bucket_name = "${var.bucket_prefix}-${random_id.bucket_suffix.hex}"

  common_tags = {
    Name        = local.bucket_name
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}
```

### Partie 4 : Fusionner les tags avec merge()

1. Renommez votre variable `tags` en `additional_tags` dans `variables.tf` pour plus de clarté :

```hcl
variable "additional_tags" {
  description = "Additional custom tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

2. Créez un local qui fusionne les tags communs et additionnels :

```hcl
locals {
  bucket_name = "${var.bucket_prefix}-${random_id.bucket_suffix.hex}"

  common_tags = {
    Name        = local.bucket_name
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }

  all_tags = merge(local.common_tags, var.additional_tags)
}
```

3. Utilisez `local.all_tags` dans votre ressource S3 :

```hcl
resource "aws_s3_bucket" "my_bucket" {
  bucket = local.bucket_name
  tags   = local.all_tags
}
```

### Partie 5 : Créer des valeurs calculées

Les locals sont parfaits pour calculer des valeurs booléennes ou dériver des informations :

1. Ajoutez des locals calculés :

```hcl
locals {
  bucket_name = "${var.bucket_prefix}-${random_id.bucket_suffix.hex}"

  common_tags = {
    Name        = local.bucket_name
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }

  all_tags = merge(local.common_tags, var.additional_tags)

  # Valeurs calculées
  is_production   = var.environment == "Production"
  requires_backup = local.is_production || var.enable_versioning
}
```

2. Ajoutez des outputs pour voir ces valeurs calculées :

```hcl
output "is_production" {
  value       = local.is_production
  description = "Whether this is a production environment"
}

output "requires_backup" {
  value       = local.requires_backup
  description = "Whether this bucket requires backup (computed value)"
}
```

3. Testez avec différentes valeurs :

```bash
# Test en development
terraform plan

# Test en production
terraform plan -var="environment=Production"
```

### Partie 6 : Utiliser les locals pour la cohérence des noms

1. Créez un local pour un préfixe de ressource cohérent :

```hcl
locals {
  # ... autres locals ...

  resource_prefix = "${var.project_name}-${var.environment}"
}
```

2. Ce préfixe pourrait être utilisé pour nommer d'autres ressources de manière cohérente (dans de futurs exercices).

### Partie 7 : Observer les avantages

1. Comparez votre code **avant** (exercice 3) et **après** (avec locals) :
   - Où est-ce que le code est plus lisible ?
   - Où est-ce que vous évitez les répétitions ?
   - Où est-ce que la logique est plus claire ?

2. Imaginez que vous devez changer la façon dont le nom du bucket est construit :
   - Sans locals : combien d'endroits devez-vous modifier ?
   - Avec locals : combien d'endroits devez-vous modifier ?

3. Appliquez votre configuration :

```bash
terraform init
terraform plan
terraform apply
```

### Partie 8 : Afficher les locals (debugging)

1. Ajoutez un output pour voir vos tags communs :

```hcl
output "common_tags" {
  value       = local.common_tags
  description = "Common tags applied to resources"
}
```

2. Affichez tous les outputs :

```bash
terraform output
```

3. Les locals n'apparaissent pas directement dans `terraform show`, mais vous pouvez les voir via les outputs ou en utilisant `terraform console` :

```bash
terraform console
> local.bucket_name
> local.common_tags
> local.is_production
> exit
```

### Partie 9 : Cas pratiques de locals

Voici d'autres exemples de locals utiles (pour référence future) :

```hcl
locals {
  # Calculer un timestamp
  created_date = formatdate("YYYY-MM-DD", timestamp())

  # Créer une liste filtrée
  enabled_features = [
    for feature in var.features : feature if feature.enabled
  ]

  # Construire un nom DNS
  dns_name = "${var.service_name}.${var.domain}"

  # Mapper des valeurs
  size_to_instance = {
    small  = "t3.micro"
    medium = "t3.small"
    large  = "t3.medium"
  }
  instance_type = local.size_to_instance[var.size]
}
```

## Questions de réflexion

1. **Variables vs Locals**
   - Quand devriez-vous utiliser une variable ? Quand un local ?
   - Peut-on convertir toutes les variables en locals ? Pourquoi (pas) ?
   - Peut-on faire l'inverse ?

2. **Principe DRY (Don't Repeat Yourself)**
   - Comment les locals aident-ils à respecter ce principe ?
   - Donnez un exemple de redondance que vous avez éliminée dans cet exercice.

3. **Ordre de calcul**
   - Un local peut-il référencer un autre local ?
   - Un local peut-il référencer une ressource ?
   - Testez dans `terraform console` : `local.bucket_name` vs `aws_s3_bucket.my_bucket.id`

4. **Locals et State**
   - Les locals apparaissent-ils dans le `terraform.tfstate` ?
   - Pourquoi (pas) ?

## Problèmes courants

### Erreur : "Reference to undeclared local value"
Vérifiez que vous utilisez `local.nom` (singulier) et non `locals.nom`.

### Erreur : "Cycle in local values"
Un local ne peut pas se référencer lui-même directement ou indirectement.

### Les locals ne changent pas
Les locals sont recalculés à chaque `terraform plan/apply`. Si les variables changent, les locals changent aussi.

### Trop de locals
Ne créez pas de locals pour tout ! Utilisez-les uniquement pour :
- Éviter les répétitions
- Calculer des valeurs dérivées
- Améliorer la lisibilité

## Pour aller plus loin

- Explorez les [fonctions Terraform](https://developer.hashicorp.com/terraform/language/functions) utilisables dans les locals
- Découvrez les [expressions conditionnelles](https://developer.hashicorp.com/terraform/language/expressions/conditionals) avancées
- Apprenez à utiliser [for expressions](https://developer.hashicorp.com/terraform/language/expressions/for) dans les locals
- Lisez sur les [best practices](https://developer.hashicorp.com/terraform/language/values/locals#when-to-use-local-values) pour l'usage des locals

## Récapitulatif

| Concept       | Utilisation                         |
| ------------- | ----------------------------------- |
| **Variables** | Inputs configurables de l'extérieur |
| **Locals**    | Valeurs calculées en interne        |
| **Outputs**   | Valeurs exposées à l'extérieur      |

Pensez à cette analogie avec une fonction :
```
function deploy(variables) {  // Les variables sont les paramètres
  locals = calculate(variables)  // Les locals sont les variables locales
  resources = create(locals)
  return outputs  // Les outputs sont la valeur de retour
}
```
