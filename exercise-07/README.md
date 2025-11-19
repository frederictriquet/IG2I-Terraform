# Exercice 7 : Ressources conditionnelles et blocs dynamiques

## Objectifs pédagogiques

- Maîtriser les expressions conditionnelles ternaires
- Créer des ressources conditionnellement avec `count`
- Utiliser des blocs `dynamic` pour des configurations flexibles
- Comprendre quand utiliser des conditionnels vs des variables booléennes
- Écrire du code Terraform expressif et adaptable

## Contexte

Dans la réalité, votre infrastructure doit s'adapter à différents environnements et situations :
- **Versioning activé uniquement en production**
- **Règles de lifecycle différentes selon l'environnement**
- **CORS activé seulement pour certains buckets**
- **Encryption différente selon la sensibilité des données**

Terraform offre plusieurs mécanismes pour créer du code conditionnel :
- **Expressions ternaires** : `condition ? true_val : false_val`
- **Count conditionnel** : `count = var.enabled ? 1 : 0`
- **Blocs dynamic** : Créer des blocs de configuration conditionnellement

## Prérequis

- Avoir complété l'exercice 06
- Comprendre les expressions conditionnelles
- Savoir utiliser count et for_each

---

## Partie 1 : Créer des ressources conditionnellement

### Objectif
Activer ou désactiver des ressources selon des variables booléennes.

### Instructions

1. Dans `exercise-07/`, créez `main.tf` :

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

# Random suffix
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket (always created)
resource "aws_s3_bucket" "conditional" {
  bucket = "${var.bucket_prefix}-${var.environment}-${random_id.bucket_suffix.hex}"

  tags = local.bucket_tags
}

# Versioning (conditional - only if enabled)
resource "aws_s3_bucket_versioning" "conditional" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.conditional.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption (conditional - only if enabled)
resource "aws_s3_bucket_server_side_encryption_configuration" "conditional" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.conditional.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Public access block (conditional - only if enabled)
resource "aws_s3_bucket_public_access_block" "conditional" {
  count  = var.block_public_access ? 1 : 0
  bucket = aws_s3_bucket.conditional.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
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
  description = "Prefix for bucket name"
  type        = string
  default     = "ig2i-ex07"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# Boolean variables for conditional resources
variable "enable_versioning" {
  description = "Enable versioning on the bucket"
  type        = bool
  default     = false
}

variable "enable_encryption" {
  description = "Enable server-side encryption"
  type        = bool
  default     = true
}

variable "block_public_access" {
  description = "Block all public access to the bucket"
  type        = bool
  default     = true
}
```

3. Testez avec différentes combinaisons :

```bash
terraform init
terraform apply

# Changez dans terraform.tfvars:
enable_versioning = true
enable_encryption = true
block_public_access = true

terraform apply
```

4. Observez que certaines ressources sont créées ou non selon les variables

---

## Partie 2 : Conditions basées sur l'environnement

### Objectif
Adapter automatiquement la configuration selon l'environnement.

### Instructions

1. Créez `locals.tf` :

```hcl
locals {
  # Automatically enable features for production
  is_production = var.environment == "prod"
  is_development = var.environment == "dev"

  # Override boolean variables for production
  versioning_enabled = local.is_production ? true : var.enable_versioning
  encryption_enabled = local.is_production ? true : var.enable_encryption

  # Lifecycle rules depend on environment
  lifecycle_days = local.is_production ? 90 : 30

  # Tags with conditional values
  bucket_tags = merge(
    {
      Name        = "${var.bucket_prefix}-${var.environment}"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Versioning  = tostring(local.versioning_enabled)
      Encryption  = tostring(local.encryption_enabled)
    },
    # Add production-specific tags
    local.is_production ? {
      Critical    = "true"
      Compliance  = "required"
      Backup      = "enabled"
    } : {}
  )
}
```

2. Modifiez `main.tf` pour utiliser les locals :

```hcl
# Versioning (using computed local value)
resource "aws_s3_bucket_versioning" "conditional" {
  count  = local.versioning_enabled ? 1 : 0
  bucket = aws_s3_bucket.conditional.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption (using computed local value)
resource "aws_s3_bucket_server_side_encryption_configuration" "conditional" {
  count  = local.encryption_enabled ? 1 : 0
  bucket = aws_s3_bucket.conditional.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

3. Testez avec différents environnements :

```bash
# Dev environment
terraform apply -var="environment=dev"

# Production environment (versioning and encryption forced)
terraform apply -var="environment=prod"
```

---

## Partie 3 : Blocs dynamiques

### Objectif
Utiliser des blocs `dynamic` pour créer des configurations conditionnelles.

### Instructions

1. Ajoutez dans `variables.tf` :

```hcl
variable "lifecycle_rules" {
  description = "List of lifecycle rules to apply"
  type = list(object({
    id                       = string
    enabled                  = bool
    expiration_days          = number
    transition_days          = optional(number)
    transition_storage_class = optional(string)
  }))
  default = []
}

variable "cors_rules" {
  description = "List of CORS rules"
  type = list(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    max_age_seconds = optional(number, 3000)
  }))
  default = []
}
```

2. Ajoutez dans `main.tf` :

```hcl
# Lifecycle configuration with dynamic blocks
resource "aws_s3_bucket_lifecycle_configuration" "conditional" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.conditional.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      expiration {
        days = rule.value.expiration_days
      }

      # Optional transition block
      dynamic "transition" {
        for_each = rule.value.transition_days != null ? [1] : []
        content {
          days          = rule.value.transition_days
          storage_class = rule.value.transition_storage_class
        }
      }
    }
  }
}

# CORS configuration with dynamic blocks
resource "aws_s3_bucket_cors_configuration" "conditional" {
  count  = length(var.cors_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.conditional.id

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}
```

3. Créez `terraform.tfvars` avec des règles :

```hcl
aws_region = "eu-west-3"
environment = "dev"
bucket_prefix = "ig2i-ex07"

enable_versioning = false
enable_encryption = true
block_public_access = true

# Lifecycle rules
lifecycle_rules = [
  {
    id                       = "delete-old-versions"
    enabled                  = true
    expiration_days          = 90
    transition_days          = 30
    transition_storage_class = "STANDARD_IA"
  },
  {
    id              = "delete-incomplete-uploads"
    enabled         = true
    expiration_days = 7
  }
]

# CORS rules
cors_rules = [
  {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["https://example.com"]
    max_age_seconds = 3000
  }
]
```

4. Testez :

```bash
terraform plan
terraform apply
```

---

## Partie 4 : Conditions complexes

### Objectif
Combiner plusieurs conditions pour des logiques avancées.

### Instructions

1. Ajoutez dans `locals.tf` :

```hcl
locals {
  # Complex conditional logic
  require_compliance = contains(["prod", "staging"], var.environment)
  is_public_bucket   = var.environment == "public"

  # Determine encryption type
  encryption_type = (
    local.is_production ? "aws:kms" :
    local.require_compliance ? "AES256" :
    var.enable_encryption ? "AES256" : "none"
  )

  # Determine retention period
  retention_days = (
    local.is_production ? 365 :
    var.environment == "staging" ? 180 :
    90
  )

  # Build comprehensive tags
  comprehensive_tags = merge(
    local.bucket_tags,
    var.enable_versioning ? { Versioned = "true" } : {},
    local.require_compliance ? { Compliance = "required" } : {},
    local.is_public_bucket ? { Public = "true" } : { Public = "false" }
  )
}
```

2. Ajoutez dans `outputs.tf` :

```hcl
output "bucket_configuration" {
  description = "Summary of bucket configuration"
  value = {
    bucket_name       = aws_s3_bucket.conditional.id
    environment       = var.environment
    versioning        = local.versioning_enabled
    encryption        = local.encryption_enabled
    encryption_type   = local.encryption_type
    public_access     = !var.block_public_access
    lifecycle_rules   = length(var.lifecycle_rules)
    cors_enabled      = length(var.cors_rules) > 0
    is_production     = local.is_production
    require_compliance = local.require_compliance
    retention_days    = local.retention_days
  }
}

output "conditional_resources_created" {
  description = "Which optional resources were created"
  value = {
    versioning         = var.enable_versioning ? "enabled" : "disabled"
    encryption         = var.enable_encryption ? "enabled" : "disabled"
    public_access_block = var.block_public_access ? "enabled" : "disabled"
    lifecycle_rules    = length(var.lifecycle_rules) > 0 ? "configured" : "not configured"
    cors_rules         = length(var.cors_rules) > 0 ? "configured" : "not configured"
  }
}
```

3. Testez avec différentes configurations :

```bash
# Development - minimal features
terraform apply -var="environment=dev" \
                -var="enable_versioning=false" \
                -var="enable_encryption=false"

# Production - all features enabled automatically
terraform apply -var="environment=prod"

# Staging - compliance required
terraform apply -var="environment=staging"
```

---

## Partie 5 : Validation conditionnelle

### Objectif
Ajouter des validations qui dépendent de l'environnement.

### Instructions

1. Modifiez `variables.tf` pour ajouter des validations conditionnelles :

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod", "public"], var.environment)
    error_message = "Environment must be dev, staging, prod, or public."
  }
}

variable "enable_versioning" {
  description = "Enable versioning on the bucket"
  type        = bool
  default     = false

  # Note: Terraform doesn't support conditional validation directly
  # But we can enforce it in locals with assertions
}
```

2. Ajoutez des checks dans `locals.tf` :

```hcl
locals {
  # Enforce production requirements
  production_checks = {
    versioning = local.is_production && !local.versioning_enabled ?
      "ERROR: Versioning must be enabled in production" : "OK"
    encryption = local.is_production && !local.encryption_enabled ?
      "ERROR: Encryption must be enabled in production" : "OK"
    public_access = local.is_production && !var.block_public_access ?
      "ERROR: Public access must be blocked in production" : "OK"
  }

  # This will appear in outputs for validation
  validation_status = alltrue([
    for check in values(local.production_checks) : check == "OK"
  ]) ? "All checks passed" : "Some checks failed"
}
```

3. Ajoutez dans `outputs.tf` :

```hcl
output "validation_checks" {
  description = "Validation checks for production compliance"
  value       = local.production_checks
}

output "validation_status" {
  description = "Overall validation status"
  value       = local.validation_status
}
```

---

## Questions de réflexion

1. **Quelle est la différence entre `count = var.enabled ? 1 : 0` et un bloc dynamic ?**
   - `count` : Active/désactive une ressource entière
   - `dynamic` : Active/désactive un bloc de configuration dans une ressource

2. **Pourquoi utiliser des locals pour des conditions complexes ?**
   - Lisibilité du code
   - Éviter la répétition de logique
   - Faciliter les tests et le débogage

3. **Quand privilégier les conditions dans les variables vs les locals ?**
   - Variables : Valeurs configurables par l'utilisateur
   - Locals : Logique dérivée, règles métier

4. **Comment gérer les dépendances avec des ressources conditionnelles ?**
   - Utiliser `try()`, `one()` ou des conditions dans les références
   - Exemple : `try(aws_s3_bucket_versioning.conditional[0].id, null)`

---

## Commandes utiles

```bash
# Voir quelles ressources seront créées
terraform plan

# Appliquer avec des variables
terraform apply -var="environment=prod"

# Voir les ressources actuelles
terraform state list

# Afficher la configuration
terraform show
```

---

## Validation

Votre configuration doit :

✅ Créer des ressources conditionnellement avec count
✅ Adapter la configuration selon l'environnement
✅ Utiliser des blocs dynamic pour lifecycle et CORS
✅ Forcer le versioning et l'encryption en production
✅ Avoir des outputs qui montrent la configuration appliquée
✅ Utiliser des conditions complexes dans les locals
✅ Valider les règles de conformité

---

## Pour aller plus loin

**Patterns avancés :**
- Utiliser `try()` pour gérer les ressources optionnelles
- Combiner `for_each` avec des dynamic blocks
- Créer des modules conditionnels

**Bonnes pratiques :**
- Documenter pourquoi certaines ressources sont conditionnelles
- Utiliser des validations pour éviter les mauvaises configurations
- Tester toutes les combinaisons de conditions

---

## Ressources

- [Terraform Conditional Expressions](https://developer.hashicorp.com/terraform/language/expressions/conditionals)
- [Dynamic Blocks](https://developer.hashicorp.com/terraform/language/expressions/dynamic-blocks)
- [Count Meta-Argument](https://developer.hashicorp.com/terraform/language/meta-arguments/count)
- [The `try`function](https://developer.hashicorp.com/terraform/language/functions/try)
