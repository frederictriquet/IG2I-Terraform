# Exercice 6 : Count et For-Each pour créer plusieurs ressources

## Objectifs pédagogiques

- Maîtriser l'utilisation de `count` pour créer plusieurs instances d'une ressource
- Découvrir `for_each` pour créer des ressources à partir de maps ou sets
- Comprendre quand utiliser `count` vs `for_each`
- Apprendre à référencer des ressources dans des collections
- Créer une infrastructure dynamique et scalable

## Contexte

Jusqu'à présent, vous avez créé une seule ressource à la fois (un bucket S3). Dans la réalité, on doit souvent :
- Créer **plusieurs ressources similaires** (3 buckets pour dev, staging, prod)
- Créer des ressources à partir d'une **liste de configurations**
- Éviter la duplication de code

Terraform offre deux mécanismes pour cela :
- **`count`** : Créer N instances identiques (ou presque) d'une ressource
- **`for_each`** : Créer des ressources à partir d'un map ou set, avec des configurations distinctes

## Prérequis

- Avoir complété l'exercice 05
- Comprendre les variables de type `list` et `map`
- Avoir configuré AWS CLI

---

## Partie 1 : Utiliser `count` pour créer plusieurs buckets

### Objectif
Créer 3 buckets S3 avec `count`.

### Instructions

1. Dans `exercise-06/`, créez `main.tf` :

```hcl
terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Create 3 random suffixes (one for each bucket)
resource "random_id" "bucket_suffix" {
  count       = 3
  byte_length = 4
}

# Create 3 S3 buckets
resource "aws_s3_bucket" "multiple" {
  count  = 3
  bucket = "${var.bucket_prefix}-${count.index}-${random_id.bucket_suffix[count.index].hex}"

  tags = {
    Name        = "Bucket-${count.index}"
    Environment = var.environment
    Index       = count.index
    ManagedBy   = "Terraform"
  }
}
```

2. Créez `variables.tf` :

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "bucket_prefix" {
  description = "Prefix for bucket names"
  type        = string
  default     = "ig2i-ex06"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "bucket_count" {
  description = "Number of buckets to create"
  type        = number
  default     = 3

  validation {
    condition     = var.bucket_count > 0 && var.bucket_count <= 10
    error_message = "Bucket count must be between 1 and 10."
  }
}
```

3. Créez `outputs.tf` :

```hcl
# Output all bucket names as a list
output "bucket_names" {
  description = "List of all bucket names"
  value       = aws_s3_bucket.multiple[*].id
}

# Output all bucket ARNs
output "bucket_arns" {
  description = "List of all bucket ARNs"
  value       = aws_s3_bucket.multiple[*].arn
}

# Output specific bucket (index 0)
output "first_bucket" {
  description = "Name of the first bucket"
  value       = aws_s3_bucket.multiple[0].id
}

# Output count
output "total_buckets" {
  description = "Total number of buckets created"
  value       = length(aws_s3_bucket.multiple)
}
```

4. Testez :

```bash
terraform init
terraform plan
terraform apply
terraform output
```

5. Observez que 3 buckets ont été créés avec des indices 0, 1, 2

---

## Partie 2 : Utiliser `for_each` avec un set

### Objectif
Créer des buckets avec des noms spécifiques en utilisant `for_each`.

### Instructions

1. Ajoutez dans `variables.tf` :

```hcl
variable "bucket_names" {
  description = "Set of bucket names to create"
  type        = set(string)
  default     = ["dev", "staging", "prod"]
}
```

2. Ajoutez dans `main.tf` :

```hcl
# Random suffix for each bucket in the set
resource "random_id" "foreach_suffix" {
  for_each    = var.bucket_names
  byte_length = 4
}

# Create buckets using for_each with a set
resource "aws_s3_bucket" "foreach_set" {
  for_each = var.bucket_names

  bucket = "${var.bucket_prefix}-${each.key}-${random_id.foreach_suffix[each.key].hex}"

  tags = {
    Name        = "Bucket-${each.key}"
    Environment = each.key
    ManagedBy   = "Terraform"
  }
}
```

3. Ajoutez dans `outputs.tf` :

```hcl
# Output bucket names from for_each (as map keys)
output "foreach_bucket_names" {
  description = "Map of bucket names from for_each"
  value       = { for k, v in aws_s3_bucket.foreach_set : k => v.id }
}

# Output specific bucket from for_each
output "prod_bucket" {
  description = "Production bucket name"
  value       = aws_s3_bucket.foreach_set["prod"].id
}
```

4. Testez :

```bash
terraform plan
terraform apply
terraform output
```

5. Notez que les buckets ont maintenant des noms significatifs (dev, staging, prod)

---

## Partie 3 : Utiliser `for_each` avec un map

### Objectif
Créer des buckets avec des configurations différentes en utilisant un map.

### Instructions

1. Ajoutez dans `variables.tf` :

```hcl
variable "bucket_configs" {
  description = "Map of bucket configurations"
  type = map(object({
    versioning = bool
    environment = string
  }))
  default = {
    "app-dev" = {
      versioning  = false
      environment = "development"
    }
    "app-staging" = {
      versioning  = true
      environment = "staging"
    }
    "app-prod" = {
      versioning  = true
      environment = "production"
    }
  }
}
```

2. Ajoutez dans `main.tf` :

```hcl
# Random suffix for each configured bucket
resource "random_id" "config_suffix" {
  for_each    = var.bucket_configs
  byte_length = 4
}

# Create buckets with different configurations
resource "aws_s3_bucket" "configured" {
  for_each = var.bucket_configs

  bucket = "${var.bucket_prefix}-${each.key}-${random_id.config_suffix[each.key].hex}"

  tags = {
    Name        = each.key
    Environment = each.value.environment
    Versioning  = tostring(each.value.versioning)
    ManagedBy   = "Terraform"
  }
}

# Apply versioning based on configuration
resource "aws_s3_bucket_versioning" "configured" {
  for_each = {
    for k, v in var.bucket_configs : k => v
    if v.versioning == true
  }

  bucket = aws_s3_bucket.configured[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}
```

3. Ajoutez dans `outputs.tf` :

```hcl
# Output configured buckets with their settings
output "configured_buckets" {
  description = "Map of configured buckets with their properties"
  value = {
    for k, v in aws_s3_bucket.configured : k => {
      id          = v.id
      arn         = v.arn
      versioning  = var.bucket_configs[k].versioning
      environment = var.bucket_configs[k].environment
    }
  }
}
```

4. Testez :

```bash
terraform plan
terraform apply
terraform output configured_buckets
```

5. Observez que seuls les buckets staging et prod ont le versioning activé

6. Testez la différence :
   - Avec `count` : Essayez de supprimer l'élément du milieu (impossible sans recréer)
   - Avec `for_each` : Retirez "staging" du set et observez que seul ce bucket est détruit

---

## Partie 4 : Références et expressions avancées

### Objectif
Utiliser des expressions pour travailler avec des collections de ressources.

### Instructions

1. Ajoutez dans `outputs.tf` :

```hcl
# Créer une liste de tous les ARNs (de toutes les méthodes)
output "all_bucket_arns" {
  description = "All bucket ARNs from all creation methods"
  value = concat(
    aws_s3_bucket.multiple[*].arn,
    [for b in aws_s3_bucket.foreach_set : b.arn],
    [for b in aws_s3_bucket.configured : b.arn]
  )
}

# Compter le nombre total de buckets
output "total_bucket_count" {
  description = "Total number of all buckets created"
  value = (
    length(aws_s3_bucket.multiple) +
    length(aws_s3_bucket.foreach_set) +
    length(aws_s3_bucket.configured)
  )
}

# Filtrer seulement les buckets de production
output "production_buckets" {
  description = "Only production environment buckets"
  value = {
    for k, v in aws_s3_bucket.configured : k => v.id
    if v.tags["Environment"] == "production"
  }
}
```

2. Créez `locals.tf` :

```hcl
locals {
  # Créer une map de tous les buckets
  all_buckets = merge(
    { for i, b in aws_s3_bucket.multiple : "count-${i}" => b.id },
    { for k, b in aws_s3_bucket.foreach_set : "set-${k}" => b.id },
    { for k, b in aws_s3_bucket.configured : "config-${k}" => b.id }
  )

  # Tags communs pour tous les buckets
  common_tags = {
    Project     = "Terraform Training"
    Exercise    = "06"
    ManagedBy   = "Terraform"
  }
}

# Output de la map locale
output "all_buckets_map" {
  description = "Map of all buckets with categorized keys"
  value       = local.all_buckets
}
```

3. Testez :

```bash
terraform plan
terraform apply
terraform output
```

---

## Questions de réflexion

1. **Quelle est la différence entre `count.index` et `each.key` ?**
   - `count.index` : Index numérique (0, 1, 2...)
   - `each.key` : Clé du map ou élément du set

2. **Que se passe-t-il si vous supprimez un élément au milieu d'une liste avec `count` ?**
   - Tous les éléments après sont recréés (car les indices changent)
   - C'est pourquoi `for_each` est souvent préférable

3. **Comment référencer un élément spécifique ?**
   - Avec count : `resource.name[0]`, `resource.name[1]`
   - Avec for_each : `resource.name["key"]`

4. **Peut-on utiliser count et for_each ensemble sur la même ressource ?**
   - Non ! C'est interdit. Choisissez l'un ou l'autre.

---

## Commandes utiles

```bash
# Voir les ressources créées
terraform state list

# Voir une ressource spécifique avec count
terraform state show 'aws_s3_bucket.multiple[0]'

# Voir une ressource spécifique avec for_each
terraform state show 'aws_s3_bucket.foreach_set["prod"]'

# Détruire une ressource spécifique
terraform destroy -target='aws_s3_bucket.multiple[1]'
terraform destroy -target='aws_s3_bucket.foreach_set["staging"]'
```

---

## Pour aller plus loin

**Expressions avancées :**
- Utiliser `for` avec des conditions
- Filtrer des collections avec `if`
- Transformer des structures de données

**Bonnes pratiques :**
- Préférer `for_each` pour des ressources qui peuvent être ajoutées/supprimées
- Utiliser `count` pour un nombre fixe de ressources identiques
- Documenter pourquoi vous choisissez count vs for_each

---

## Ressources

- [Terraform count Meta-Argument](https://developer.hashicorp.com/terraform/language/meta-arguments/count)
- [Terraform for_each Meta-Argument](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each)
- [For Expressions](https://developer.hashicorp.com/terraform/language/expressions/for)
