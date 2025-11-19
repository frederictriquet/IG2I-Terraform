# Exercice 5 : Outputs et Data Sources

## Objectifs pédagogiques

- Maîtriser l'utilisation des outputs pour exposer des informations
- Découvrir les data sources pour interroger des ressources existantes
- Comprendre la différence entre créer et lire des ressources
- Apprendre à partager des données entre configurations Terraform
- Utiliser des outputs sensibles pour protéger les données confidentielles

## Contexte

Dans les exercices précédents, vous avez créé des ressources AWS (S3 buckets). Maintenant, vous devez :
- **Exposer des informations** importantes via outputs (URLs, ARNs, IDs)
- **Interroger des ressources existantes** avec data sources (AMIs, zones de disponibilité)
- **Préparer le partage de données** pour d'autres projets Terraform

Les **outputs** permettent d'afficher des valeurs après `terraform apply` et de les rendre disponibles pour d'autres modules ou configurations.

Les **data sources** permettent de lire des informations sur des ressources qui existent déjà, sans les créer.

## Prérequis

- Avoir complété l'exercice 04
- Avoir un bucket S3 déployé sur AWS
- Avoir configuré AWS CLI avec des credentials valides

---

## Partie 1 : Outputs détaillés pour vos ressources

### Objectif
Ajouter des outputs pour exposer toutes les informations importantes de votre bucket S3.

### Instructions

1. Dans `exercise-05/`, créez les fichiers de base en copiant l'exercice 04.

2. Créez ou modifiez `outputs.tf` pour exposer :
   - L'ID du bucket S3
   - L'ARN (Amazon Resource Name) du bucket
   - Le nom complet du bucket
   - La région du bucket
   - L'URL du bucket
   - Les tags appliqués au bucket

3. Ajoutez des descriptions claires pour chaque output

4. Marquez certains outputs comme sensibles si nécessaire

**Exemple de structure attendue :**

```hcl
output "bucket_id" {
  description = "The ID of the S3 bucket"
  value       = aws_s3_bucket.example.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.example.arn
}

# Ajoutez les autres outputs...
```

5. Testez :

```bash
terraform init
terraform plan
terraform apply
```

6. Affichez tous les outputs :

```bash
terraform output
```

7. Affichez un output spécifique :

```bash
terraform output bucket_arn
```

8. Exportez les outputs en JSON :

```bash
terraform output -json
```

---

## Partie 2 : Data Sources pour interroger AWS

### Objectif
Utiliser des data sources pour récupérer des informations sur l'infrastructure AWS existante.

### Instructions

1. Créez un fichier `data.tf`

2. Ajoutez une data source pour récupérer les zones de disponibilité disponibles dans votre région :

```hcl
data "aws_availability_zones" "available" {
  state = "available"
}
```

3. Ajoutez une data source pour récupérer des informations sur votre compte AWS :

```hcl
data "aws_caller_identity" "current" {}
```

4. Ajoutez une data source pour récupérer la région actuelle :

```hcl
data "aws_region" "current" {}
```

5. Créez des outputs pour afficher ces informations :

```hcl
output "available_zones" {
  description = "List of available availability zones"
  value       = data.aws_availability_zones.available.names
}

output "account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "current_region" {
  description = "Current AWS region"
  value       = data.aws_region.current.name
}
```

6. Testez et affichez les outputs

---

## Partie 3 : Data Source pour lire un bucket existant

### Objectif
Utiliser une data source pour lire des informations sur un bucket S3 qui existe déjà.

### Instructions

1. Dans `data.tf`, ajoutez une data source pour lire votre bucket existant :

```hcl
data "aws_s3_bucket" "existing" {
  bucket = aws_s3_bucket.example.id

  depends_on = [aws_s3_bucket.example]
}
```

2. Créez un output pour afficher les informations récupérées :

```hcl
output "existing_bucket_region" {
  description = "Region of the existing bucket (from data source)"
  value       = data.aws_s3_bucket.existing.region
}

output "existing_bucket_domain_name" {
  description = "Domain name of the existing bucket"
  value       = data.aws_s3_bucket.existing.bucket_domain_name
}
```

3. Observez la différence entre créer une ressource (`resource`) et la lire (`data source`)

4. Testez :

```bash
terraform plan
terraform apply
terraform output
```

---

## Partie 4 : Outputs sensibles

### Objectif
Protéger les informations sensibles avec l'attribut `sensitive`.

### Instructions

1. Dans `outputs.tf`, modifiez l'output de l'account ID pour le marquer comme sensible :

```hcl
output "account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
  sensitive   = true
}
```

2. Appliquez les changements :

```bash
terraform apply
```

3. Observez que l'account ID n'est plus affiché dans la sortie de `terraform output`

4. Pour voir un output sensible spécifique :

```bash
terraform output account_id
```

5. Pour voir tous les outputs en JSON (y compris les sensibles) :

```bash
terraform output -json
```

---

## Partie 5 : Utiliser les outputs dans des locals

### Objectif
Comprendre comment utiliser les données des data sources dans vos configurations.

### Instructions

1. Dans `locals.tf`, ajoutez des locals qui utilisent les data sources :

```hcl
locals {
  # Utiliser le compte AWS dans les tags
  resource_owner = "AWS-Account-${data.aws_caller_identity.current.account_id}"

  # Créer un nom de bucket qui inclut la région
  bucket_name = "${var.bucket_prefix}-${data.aws_region.current.name}-${random_id.bucket_suffix.hex}"

  # Tags enrichis avec des informations AWS
  enriched_tags = merge(
    local.common_tags,
    {
      Region     = data.aws_region.current.name
      AccountId  = data.aws_caller_identity.current.account_id
      Owner      = local.resource_owner
    }
  )
}
```

2. Modifiez votre ressource S3 pour utiliser ces nouveaux tags :

```hcl
resource "aws_s3_bucket" "example" {
  bucket = local.bucket_name

  tags = local.enriched_tags
}
```

3. Testez :

```bash
terraform plan
terraform apply
```

4. Vérifiez que les tags sont correctement appliqués :

```bash
terraform output
aws s3api get-bucket-tagging --bucket <votre-bucket-name>
```

---

## Questions de réflexion

1. **Quelle est la différence entre une `resource` et une `data` source ?**
   - Une resource _crée/modifie/détruit_ des ressources
   - une data source _lit_ des informations existantes

2. **Pourquoi utiliser `sensitive = true` sur certains outputs ?**
   - Pour éviter d'afficher des données sensibles dans les logs CI/CD
   - Pour protéger les secrets, tokens, mots de passe

3. **Quand utiliser les outputs ?**
   - Pour partager des informations entre modules
   - Pour afficher des informations importantes après le déploiement
   - Pour intégrer avec d'autres outils (Ansible, scripts)

4. **Peut-on utiliser une data source pour une ressource qui n'existe pas encore ?**
   - Non, la data source lit des ressources existantes
   - Il faut utiliser `depends_on` si la ressource est créée dans la même configuration


---

## Validation

Votre configuration doit :

✅ Avoir au moins 6 outputs pour le bucket S3
✅ Utiliser au moins 3 data sources AWS différents
✅ Avoir au moins un output marqué comme sensible
✅ Utiliser les data sources dans des locals
✅ Afficher correctement tous les outputs après `terraform apply`
✅ Enrichir les tags du bucket avec des informations du compte AWS

---

## Pour aller plus loin

**Data sources utiles à explorer :**
- `aws_ami` - Récupérer une AMI (image EC2)
- `aws_vpc` - Lire un VPC existant
- `aws_subnet` - Lire un subnet existant
- `aws_iam_policy_document` - Générer des politiques IAM

**Outputs avancés :**
- Utiliser `terraform_remote_state` pour lire les outputs d'autres projets
- Créer des outputs de type map ou list
- Utiliser des expressions conditionnelles dans les outputs

---

## Ressources

- [Terraform Outputs Documentation](https://developer.hashicorp.com/terraform/language/values/outputs)
- [Terraform Data Sources Documentation](https://developer.hashicorp.com/terraform/language/data-sources)
- [AWS Provider Data Sources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket)
