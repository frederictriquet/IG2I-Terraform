# Exercice 99 : Aller plus loin avec Terraform

## Introduction

Ce document n'est pas un exercice pratique traditionnel, mais plutôt un guide de référence sur des concepts avancés de Terraform non couverts dans les exercices 01 à 07.

Ces sujets dépassent le cadre de cette formation introductive, mais sont essentiels pour une utilisation professionnelle de Terraform. Consultez cette ressource lorsque vous avez du temps libre ou lorsque vous rencontrez ces besoins dans vos projets réels.

---

## 1. Modules pour l'infrastructure réutilisable

### Quand utiliser ?

- Créer des composants d'infrastructure réutilisables (ex: "module bucket S3 standard")
- Standardiser les configurations dans une équipe
- Partager des patterns d'infrastructure entre projets
- Encapsuler la complexité

### Concepts clés

Structure d'un module :

```
modules/
└── s3-bucket/
    ├── main.tf       # Ressources du module
    ├── variables.tf  # Inputs du module
    ├── outputs.tf    # Outputs du module
    └── README.md     # Documentation
```

Exemple de module simple :

```hcl
# modules/s3-bucket/variables.tf
variable "bucket_name" {
  description = "Nom du bucket S3"
  type        = string
}

variable "versioning_enabled" {
  description = "Activer le versioning"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags à appliquer"
  type        = map(string)
  default     = {}
}

# modules/s3-bucket/main.tf
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "this" {
  count  = var.versioning_enabled ? 1 : 0
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# modules/s3-bucket/outputs.tf
output "bucket_id" {
  description = "ID du bucket créé"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN du bucket créé"
  value       = aws_s3_bucket.this.arn
}
```

Utilisation du module :

```hcl
# main.tf
module "logs_bucket" {
  source = "./modules/s3-bucket"

  bucket_name        = "my-logs-bucket"
  versioning_enabled = false

  tags = {
    Purpose     = "Logs"
    Environment = "production"
  }
}

module "backups_bucket" {
  source = "./modules/s3-bucket"

  bucket_name        = "my-backups-bucket"
  versioning_enabled = true

  tags = {
    Purpose     = "Backups"
    Environment = "production"
  }
}

output "logs_bucket_arn" {
  value = module.logs_bucket.bucket_arn
}
```

### Modules distants

```hcl
# Depuis le Terraform Registry
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "my-vpc"
  cidr = "10.0.0.0/16"
}

# Depuis Git
module "custom" {
  source = "git::https://github.com/company/terraform-modules.git//s3-bucket?ref=v1.2.0"
}
```

### Bonnes pratiques

1. **Un module = un objectif** : Ne créez pas de modules "fourre-tout"
2. **Documentation** : Documentez tous les inputs, outputs et exemples
3. **Versioning** : Utilisez des versions spécifiques pour les modules distants
4. **Tests** : Testez vos modules avec différentes configurations
5. **Outputs explicites** : N'exposez que les outputs nécessaires

### Ressources

- [Documentation Modules](https://developer.hashicorp.com/terraform/language/modules)
- [Terraform Registry](https://registry.terraform.io/browse/modules)
- [Module Best Practices](https://developer.hashicorp.com/terraform/language/modules/develop)

---

## 2. Remote State avec backend S3

### Quand utiliser ?

- **Toujours en production** et pour tout travail en équipe
- Pour protéger le state avec du chiffrement
- Pour éviter les modifications concurrentes avec le locking
- Pour avoir un backup automatique du state

### Concepts clés

Configuration du backend S3 :

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "project/terraform.tfstate"
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

Création de l'infrastructure pour le backend :

```hcl
# bootstrap/main.tf - À exécuter une seule fois
resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-terraform-state-bucket"

  lifecycle {
    prevent_destroy = true  # Protection contre la suppression accidentelle
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "terraform_lock" {
  name           = "terraform-state-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

Migration du state local vers S3 :

```bash
# 1. Ajouter la configuration backend dans backend.tf
# 2. Réinitialiser Terraform
terraform init -migrate-state

# Terraform demandera confirmation pour migrer le state
```

### Backend partiel (recommandé pour plusieurs environnements)

```hcl
# backend.tf
terraform {
  backend "s3" {
    # Valeurs communes
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"

    # bucket et key seront fournis lors de l'init
  }
}
```

Fichiers de configuration par environnement :

```hcl
# config/dev.tfbackend
bucket = "my-terraform-state-bucket"
key    = "dev/terraform.tfstate"

# config/prod.tfbackend
bucket = "my-terraform-state-bucket"
key    = "prod/terraform.tfstate"
```

Initialisation avec configuration spécifique :

```bash
terraform init -backend-config=config/dev.tfbackend
```

### Lire le state d'un autre projet

```hcl
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = "my-terraform-state-bucket"
    key    = "vpc/terraform.tfstate"
    region = "eu-west-3"
  }
}

# Utiliser les outputs du projet VPC
resource "aws_instance" "web" {
  subnet_id = data.terraform_remote_state.vpc.outputs.subnet_id
}
```

### Points d'attention

- Le bucket et la table DynamoDB doivent être créés **avant** de configurer le backend
- Ne jamais commiter le fichier `terraform.tfstate` dans Git une fois le backend configuré
- Le state lock empêche deux personnes de modifier l'infrastructure simultanément
- En cas de lock bloqué : `terraform force-unlock <LOCK_ID>`

### Ressources

- [Backend S3](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [Remote State Data Source](https://developer.hashicorp.com/terraform/language/state/remote-state-data)

---

## 3. Workspaces pour gérer plusieurs environnements

### Quand utiliser ?

- Pour gérer plusieurs environnements (dev, staging, prod) avec le même code
- Quand les environnements sont **très similaires** (même structure, paramètres différents)
- Alternative aux répertoires séparés pour les petits projets

### Concepts clés

```bash
# Lister les workspaces
terraform workspace list

# Créer un nouveau workspace
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Changer de workspace
terraform workspace select dev

# Afficher le workspace actuel
terraform workspace show
```

Utiliser le workspace dans le code :

```hcl
# Nommer les ressources selon l'environnement
resource "aws_s3_bucket" "data" {
  bucket = "my-app-${terraform.workspace}-data"

  tags = {
    Environment = terraform.workspace
  }
}

# Configurations différentes par environnement
locals {
  instance_types = {
    dev     = "t2.micro"
    staging = "t3.small"
    prod    = "t3.large"
  }

  instance_type = local.instance_types[terraform.workspace]
}

resource "aws_instance" "web" {
  instance_type = local.instance_type
}

# Avec des variables
variable "instance_counts" {
  type = map(number)
  default = {
    dev     = 1
    staging = 2
    prod    = 5
  }
}

resource "aws_instance" "app" {
  count         = var.instance_counts[terraform.workspace]
  instance_type = local.instance_type
}
```

### Workspaces avec remote state

Chaque workspace a son propre state file dans S3 :

```
s3://my-bucket/
├── env:/
│   ├── dev/
│   │   └── terraform.tfstate
│   ├── staging/
│   │   └── terraform.tfstate
│   └── prod/
│       └── terraform.tfstate
└── terraform.tfstate  # workspace "default"
```

### Workspaces vs Répertoires séparés

| Critère                    | Workspaces                      | Répertoires séparés          |
| -------------------------- | ------------------------------- | ---------------------------- |
| Code partagé               | Oui                             | Non (duplication ou modules) |
| Configurations différentes | Moins flexible                  | Très flexible                |
| Isolation                  | Faible (même code)              | Forte (code indépendant)     |
| Complexité                 | Simple                          | Plus complexe                |
| Risque d'erreur            | Plus élevé (mauvais workspace)  | Plus faible                  |
| Cas d'usage                | Petits projets, envs similaires | Production, grandes équipes  |

### Limites et recommandations

**Limitations :**
- Difficile de gérer des architectures très différentes entre environnements
- Le workspace "default" ne peut pas être supprimé
- Risque de confusion : être dans le mauvais workspace

**Recommandations :**
- ✅ Utiliser des workspaces pour : dev/staging avec des configurations similaires
- ❌ Éviter pour : production critique, architectures différentes par environnement
- ✅ Toujours vérifier le workspace actuel : `terraform workspace show`
- ✅ Utiliser des noms explicites dans les ressources pour identifier l'environnement

### Alternative : structure par répertoires

```
environments/
├── dev/
│   ├── main.tf
│   ├── terraform.tfvars
│   └── backend.tf
├── staging/
│   ├── main.tf
│   ├── terraform.tfvars
│   └── backend.tf
└── prod/
    ├── main.tf
    ├── terraform.tfvars
    └── backend.tf

modules/
└── infrastructure/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

Cette approche est **recommandée pour la production** car elle offre une meilleure isolation.

### Ressources

- [Documentation Workspaces](https://developer.hashicorp.com/terraform/language/state/workspaces)
- [Managing Environments](https://developer.hashicorp.com/terraform/tutorials/modules/organize-configuration)

---

## 4. Structures de données complexes et fonctions

### Quand utiliser ?

- Pour manipuler des configurations complexes
- Transformer des données entre différents formats
- Créer des configurations dynamiques et flexibles
- Éviter la répétition de code

### Fonctions essentielles

#### Manipulation de listes

```hcl
# concat : combiner des listes
locals {
  dev_ips   = ["10.0.1.0/24", "10.0.2.0/24"]
  prod_ips  = ["10.1.1.0/24", "10.1.2.0/24"]
  all_ips   = concat(local.dev_ips, local.prod_ips)
}

# flatten : aplatir des listes imbriquées
locals {
  nested = [
    ["a", "b"],
    ["c", "d"]
  ]
  flat = flatten(local.nested)  # ["a", "b", "c", "d"]
}

# distinct : éliminer les doublons
locals {
  duplicates = ["a", "b", "a", "c", "b"]
  unique     = distinct(local.duplicates)  # ["a", "b", "c"]
}
```

#### Manipulation de maps

```hcl
# merge : fusionner plusieurs maps
locals {
  common_tags = {
    ManagedBy = "Terraform"
    Project   = "MyApp"
  }

  env_tags = {
    Environment = "production"
  }

  all_tags = merge(local.common_tags, local.env_tags)
}

# lookup : récupérer une valeur avec un défaut
locals {
  environments = {
    dev  = "t2.micro"
    prod = "t3.large"
  }

  instance_type = lookup(local.environments, var.env, "t2.micro")
}
```

#### Manipulation de chaînes

```hcl
# join : concaténer avec un séparateur
locals {
  parts = ["my", "bucket", "name"]
  name  = join("-", local.parts)  # "my-bucket-name"
}

# split : découper une chaîne
locals {
  cidr       = "10.0.1.0/24"
  cidr_parts = split("/", local.cidr)  # ["10.0.1.0", "24"]
}

# replace : remplacer du texte
locals {
  original = "my_bucket_name"
  fixed    = replace(local.original, "_", "-")  # "my-bucket-name"
}

# format : formater des chaînes
locals {
  formatted = format("bucket-%03d", 42)  # "bucket-042"
}

# lower / upper : casse
locals {
  name = "MyBucket"
  normalized = lower(local.name)  # "mybucket"
}
```

#### Fonctions for et expressions

```hcl
# For avec liste
locals {
  names = ["alice", "bob", "charlie"]

  # Transformer une liste
  upper_names = [for name in local.names : upper(name)]
  # ["ALICE", "BOB", "CHARLIE"]

  # Filtrer une liste
  short_names = [for name in local.names : name if length(name) <= 4]
  # ["alice", "bob"]
}

# For avec map
locals {
  instances = {
    web = "t2.micro"
    db  = "t3.large"
  }

  # Transformer un map
  instance_sizes = {
    for key, value in local.instances :
    key => upper(value)
  }
  # { web = "T2.MICRO", db = "T3.LARGE" }

  # Filtrer un map
  small_instances = {
    for key, value in local.instances :
    key => value
    if value == "t2.micro"
  }
  # { web = "t2.micro" }
}
```

#### Gestion d'erreurs

```hcl
# try : essayer plusieurs expressions
locals {
  config = {
    name = "mybucket"
    # tags est optionnel
  }

  tags = try(local.config.tags, {})  # {} si tags n'existe pas
}

# can : vérifier si une expression est valide
locals {
  is_valid_cidr = can(cidrhost(var.cidr, 0))
}

# coalesce : première valeur non-null
locals {
  name = coalesce(var.custom_name, var.default_name, "fallback")
}
```

### Exemple complexe : configuration multi-environnement

```hcl
variable "environments" {
  type = map(object({
    instance_type    = string
    instance_count   = number
    enable_backup    = bool
    allowed_cidrs    = list(string)
  }))

  default = {
    dev = {
      instance_type  = "t2.micro"
      instance_count = 1
      enable_backup  = false
      allowed_cidrs  = ["10.0.0.0/8"]
    }
    prod = {
      instance_type  = "t3.large"
      instance_count = 3
      enable_backup  = true
      allowed_cidrs  = ["10.1.0.0/16", "10.2.0.0/16"]
    }
  }
}

locals {
  # Créer une liste plate de toutes les instances
  all_instances = flatten([
    for env_name, env_config in var.environments : [
      for i in range(env_config.instance_count) : {
        name          = "${env_name}-instance-${i}"
        instance_type = env_config.instance_type
        environment   = env_name
      }
    ]
  ])

  # Créer un map des environnements nécessitant des backups
  backup_environments = {
    for env_name, env_config in var.environments :
    env_name => env_config
    if env_config.enable_backup
  }

  # Créer une liste unique de tous les CIDRs
  all_cidrs = distinct(flatten([
    for env_config in values(var.environments) :
    env_config.allowed_cidrs
  ]))
}

# Créer toutes les instances
resource "aws_instance" "app" {
  for_each = { for idx, inst in local.all_instances : inst.name => inst }

  instance_type = each.value.instance_type

  tags = {
    Name        = each.value.name
    Environment = each.value.environment
  }
}
```

### Fonctions utiles à connaître

| Catégorie      | Fonctions                                | Usage                |
| -------------- | ---------------------------------------- | -------------------- |
| Collections    | `length`, `element`, `index`, `contains` | Manipulation de base |
| Transformation | `flatten`, `transpose`, `chunklist`      | Restructuration      |
| Encodage       | `jsonencode`, `jsondecode`, `yamlencode` | Conversion formats   |
| Fichiers       | `file`, `templatefile`, `filebase64`     | Lire des fichiers    |
| Hash/Crypto    | `md5`, `sha256`, `base64encode`          | Hachage et encodage  |
| Réseau         | `cidrhost`, `cidrsubnet`, `cidrnetmask`  | Calculs réseau       |
| Date/Time      | `timestamp`, `formatdate`                | Horodatage           |

### Ressources

- [Toutes les fonctions Terraform](https://developer.hashicorp.com/terraform/language/functions)
- [For Expressions](https://developer.hashicorp.com/terraform/language/expressions/for)
- [Type Constraints](https://developer.hashicorp.com/terraform/language/expressions/type-constraints)

---

## 5. Import de ressources existantes

### Quand utiliser ?

- Reprendre le contrôle de ressources créées manuellement via la console AWS
- Migrer une infrastructure existante vers Terraform
- Récupérer après une perte du state file
- Intégrer des ressources créées par d'autres outils

### Concepts clés

Processus d'import en 3 étapes :

#### 1. Écrire la configuration Terraform

```hcl
# On veut importer un bucket S3 existant nommé "my-existing-bucket"
resource "aws_s3_bucket" "imported" {
  bucket = "my-existing-bucket"

  # Autres attributs seront ajustés après l'import
}
```

#### 2. Importer la ressource dans le state

```bash
# Syntaxe : terraform import <resource_type>.<name> <id_aws>
terraform import aws_s3_bucket.imported my-existing-bucket
```

#### 3. Ajuster la configuration pour correspondre à la réalité

```bash
# Voir les différences
terraform plan

# La configuration doit correspondre EXACTEMENT à la ressource existante
# Sinon Terraform voudra modifier la ressource
```

### Exemple complet : importer un bucket S3

```bash
# 1. Le bucket existe déjà dans AWS : "my-old-bucket"

# 2. Créer la configuration de base
cat > import.tf <<EOF
resource "aws_s3_bucket" "legacy" {
  bucket = "my-old-bucket"
}
EOF

# 3. Importer dans le state
terraform import aws_s3_bucket.legacy my-old-bucket

# 4. Voir ce que Terraform veut changer
terraform plan

# 5. Récupérer les attributs actuels
terraform show

# 6. Compléter la configuration pour qu'elle corresponde
# (ajouter tags, versioning, etc. selon ce qui existe)

# 7. Vérifier qu'il n'y a plus de changements
terraform plan  # Doit afficher "No changes"
```

### Import avec Terraform 1.5+ (import blocks)

Depuis Terraform 1.5, une nouvelle syntaxe déclarative est disponible :

```hcl
# Configuration de la ressource
resource "aws_s3_bucket" "imported" {
  bucket = "my-existing-bucket"
}

# Bloc d'import déclaratif
import {
  to = aws_s3_bucket.imported
  id = "my-existing-bucket"
}
```

Exécution :

```bash
terraform plan -generate-config-out=generated.tf
terraform apply
```

Terraform génère automatiquement la configuration complète !

### Trouver l'ID de ressource à importer

Chaque type de ressource AWS a un format d'ID différent :

```bash
# S3 bucket : le nom du bucket
terraform import aws_s3_bucket.example my-bucket-name

# EC2 instance : l'instance ID
terraform import aws_instance.web i-1234567890abcdef0

# Security group : le SG ID
terraform import aws_security_group.app sg-12345678

# VPC : le VPC ID
terraform import aws_vpc.main vpc-12345678
```

Consultez la documentation du provider pour chaque ressource :
https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket#import

### Importer plusieurs ressources : outils automatisés

Pour importer beaucoup de ressources, utilisez des outils comme :

**Terraformer** (recommandé) :
```bash
# Installer terraformer
# https://github.com/GoogleCloudPlatform/terraformer

# Importer toutes les ressources S3
terraformer import aws --resources=s3 --regions=eu-west-3

# Importer plusieurs types
terraformer import aws --resources=s3,ec2_instance,vpc --regions=eu-west-3
```

**AWS2TF** :
```bash
# Alternative pour AWS
# https://github.com/aws-samples/aws2tf
```

### Limites de l'import

- **Pas de génération automatique** (avant Terraform 1.5) : vous devez écrire la config manuellement
- **Attributs par défaut** : certains attributs peuvent avoir des valeurs par défaut différentes
- **Ressources imbriquées** : certaines ressources nécessitent plusieurs imports
- **Pas de rollback** : l'import modifie le state, faites une backup avant !

### Bonnes pratiques

1. **Backup du state** avant tout import : `cp terraform.tfstate terraform.tfstate.backup`
2. **Importer par petits groupes** : pas toute l'infra d'un coup
3. **Utiliser des modules** pour organiser les ressources importées
4. **Documenter** : noter quelles ressources ont été importées et pourquoi
5. **Tester l'import** : vérifier que `terraform plan` ne montre aucun changement

### Ressources

- [Import Command](https://developer.hashicorp.com/terraform/cli/commands/import)
- [Import Blocks (Terraform 1.5+)](https://developer.hashicorp.com/terraform/language/import)
- [Terraformer](https://github.com/GoogleCloudPlatform/terraformer)

---

## 6. Provisioners et local-exec

### Quand utiliser ?

**⚠️ ATTENTION : Les provisioners sont une solution de dernier recours !**

Utilisez les provisioners **uniquement** quand :
- Aucune ressource Terraform native n'existe pour votre besoin
- Vous devez exécuter des scripts de configuration après création
- Vous devez intégrer avec des systèmes externes non supportés par Terraform

**Alternatives à privilégier** :
- `cloud-init` / `user_data` pour les configurations EC2
- Modules Terraform pour les patterns communs
- Outils de configuration management (Ansible, Chef, Puppet) lancés séparément
- Opérateurs cloud-native (Lambda, Systems Manager, etc.)

### Types de provisioners

#### 1. local-exec : exécuter sur votre machine

```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"

  # Exécuté après la création de l'instance
  provisioner "local-exec" {
    command = "echo ${self.public_ip} >> inventory.txt"
  }

  # Avec un interpréteur personnalisé
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      echo "Instance created: ${self.id}"
      aws ec2 create-tags --resources ${self.id} --tags Key=Status,Value=Provisioned
    EOT
  }

  # Variables d'environnement
  provisioner "local-exec" {
    command = "python3 notify.py"
    environment = {
      INSTANCE_IP = self.public_ip
      INSTANCE_ID = self.id
    }
  }
}
```

#### 2. remote-exec : exécuter sur la ressource distante

```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
  key_name      = "my-key"

  # Connexion SSH
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/my-key.pem")
    host        = self.public_ip
  }

  # Commandes inline
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y httpd",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd"
    ]
  }

  # Depuis un script
  provisioner "remote-exec" {
    script = "${path.module}/scripts/setup.sh"
  }

  # Depuis plusieurs scripts
  provisioner "remote-exec" {
    scripts = [
      "${path.module}/scripts/install.sh",
      "${path.module}/scripts/configure.sh",
      "${path.module}/scripts/start.sh"
    ]
  }
}
```

#### 3. file : copier des fichiers

```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
  key_name      = "my-key"

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/my-key.pem")
    host        = self.public_ip
  }

  # Copier un fichier
  provisioner "file" {
    source      = "app.conf"
    destination = "/tmp/app.conf"
  }

  # Copier un répertoire
  provisioner "file" {
    source      = "configs/"
    destination = "/tmp/configs"
  }

  # Contenu inline
  provisioner "file" {
    content     = templatefile("app.conf.tpl", {
      port = 8080
      host = self.private_ip
    })
    destination = "/tmp/app.conf"
  }
}
```

### Timing et conditions

```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"

  # Exécuté à la CRÉATION (par défaut)
  provisioner "local-exec" {
    when    = create
    command = "echo 'Instance created'"
  }

  # Exécuté à la DESTRUCTION
  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Instance destroyed'"
  }

  # Continuer même en cas d'erreur
  provisioner "local-exec" {
    command     = "echo 'Best effort command'"
    on_failure  = continue  # Par défaut : fail (arrête tout)
  }
}
```

### null_resource : provisioners sans ressource

Utile pour des tâches qui ne sont pas liées à une ressource spécifique :

```hcl
resource "null_resource" "setup" {
  # Déclencheurs : re-exécute si ces valeurs changent
  triggers = {
    cluster_instance_ids = join(",", aws_instance.cluster[*].id)
    version              = var.app_version
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i inventory.ini site.yml"
  }

  # Dépendances explicites
  depends_on = [
    aws_instance.cluster,
    aws_security_group.app
  ]
}
```

### Pourquoi les provisioners sont problématiques

1. **Non idempotents** : s'exécutent une seule fois à la création
2. **Difficiles à déboguer** : les erreurs sont opaques
3. **Pas de rollback** : si le provisioner échoue, la ressource reste dans un état intermédiaire
4. **Dépendances cachées** : le code exécuté n'est pas visible dans le plan
5. **Pas de gestion d'état** : Terraform ne sait pas si le script a réussi ou non

### Alternatives recommandées

```hcl
# ❌ Mauvais : provisioner pour installer un package
resource "aws_instance" "web" {
  ami = "ami-12345678"

  provisioner "remote-exec" {
    inline = ["sudo yum install -y httpd"]
  }
}

# ✅ Bon : user_data
resource "aws_instance" "web" {
  ami       = "ami-12345678"
  user_data = <<-EOF
    #!/bin/bash
    yum install -y httpd
    systemctl start httpd
  EOF
}

# ✅ Encore mieux : AMI pré-configurée avec Packer
resource "aws_instance" "web" {
  ami = data.aws_ami.web_server.id  # AMI avec httpd déjà installé
}
```

### Cas d'usage légitimes

Les seuls cas où les provisioners sont acceptables :

1. **Intégration avec systèmes externes** :
```hcl
resource "aws_instance" "web" {
  # ...

  provisioner "local-exec" {
    command = "curl -X POST ${var.monitoring_webhook} -d 'instance_created=${self.id}'"
  }
}
```

2. **Génération de fichiers de configuration** :
```hcl
resource "null_resource" "generate_inventory" {
  triggers = {
    cluster_ids = join(",", aws_instance.cluster[*].id)
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat > inventory.ini <<EOF
      [web]
      ${join("\n", aws_instance.cluster[*].public_ip)}
      EOF
    EOT
  }
}
```

3. **Attente ou vérifications** :
```hcl
resource "null_resource" "wait_for_app" {
  provisioner "local-exec" {
    command = "until curl -f http://${aws_instance.web.public_ip}; do sleep 5; done"
  }

  depends_on = [aws_instance.web]
}
```

### Ressources

- [Provisioners Documentation](https://developer.hashicorp.com/terraform/language/resources/provisioners/syntax)
- [Why Provisioners are Last Resort](https://developer.hashicorp.com/terraform/language/resources/provisioners/syntax#provisioners-are-a-last-resort)

---

## 7. Intégration avec Ansible

### Quand utiliser ?

- **Terraform** pour provisionner l'infrastructure (VPCs, instances, buckets)
- **Ansible** pour configurer les applications (installer packages, configurer services)

**Séparation des responsabilités** :
- Terraform : "Créer 3 serveurs EC2 avec 2 Go de RAM"
- Ansible : "Installer Apache, configurer un virtualhost, déployer l'application"

### Approche 1 : Génération d'inventaire dynamique

Terraform crée les instances et génère un fichier d'inventaire Ansible :

```hcl
# main.tf
resource "aws_instance" "web" {
  count         = 3
  ami           = "ami-12345678"
  instance_type = "t2.micro"
  key_name      = "ansible-key"

  tags = {
    Name = "web-${count.index}"
    Role = "webserver"
  }
}

resource "aws_instance" "db" {
  count         = 2
  ami           = "ami-12345678"
  instance_type = "t3.small"
  key_name      = "ansible-key"

  tags = {
    Name = "db-${count.index}"
    Role = "database"
  }
}

# Génération de l'inventaire Ansible
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/inventory.ini"
  content  = templatefile("${path.module}/inventory.tpl", {
    web_servers = aws_instance.web[*]
    db_servers  = aws_instance.db[*]
  })
}
```

Template d'inventaire :

```ini
# inventory.tpl
[web]
%{ for server in web_servers ~}
${server.tags["Name"]} ansible_host=${server.public_ip} ansible_user=ec2-user
%{ endfor ~}

[database]
%{ for server in db_servers ~}
${server.tags["Name"]} ansible_host=${server.public_ip} ansible_user=ec2-user
%{ endfor ~}

[all:vars]
ansible_ssh_private_key_file=~/.ssh/ansible-key.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

Résultat dans `inventory.ini` :

```ini
[web]
web-0 ansible_host=54.12.34.56 ansible_user=ec2-user
web-1 ansible_host=54.12.34.57 ansible_user=ec2-user
web-2 ansible_host=54.12.34.58 ansible_user=ec2-user

[database]
db-0 ansible_host=54.12.34.59 ansible_user=ec2-user
db-1 ansible_host=54.12.34.60 ansible_user=ec2-user

[all:vars]
ansible_ssh_private_key_file=~/.ssh/ansible-key.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

### Approche 2 : Lancer Ansible automatiquement

```hcl
resource "null_resource" "run_ansible" {
  # Re-exécuter si l'inventaire change
  triggers = {
    inventory_content = local_file.ansible_inventory.content
  }

  # Attendre que les instances soient prêtes
  provisioner "local-exec" {
    command = "sleep 30"  # Attendre le démarrage SSH
  }

  # Exécuter Ansible
  provisioner "local-exec" {
    command = "ansible-playbook -i inventory.ini site.yml"
  }

  depends_on = [
    local_file.ansible_inventory,
    aws_instance.web,
    aws_instance.db
  ]
}
```

### Approche 3 : Passer des variables Terraform à Ansible

```hcl
# outputs.tf
output "web_servers" {
  value = {
    for instance in aws_instance.web :
    instance.tags["Name"] => {
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
      id         = instance.id
    }
  }
}

output "database_endpoint" {
  value = aws_db_instance.main.endpoint
}

# Générer un fichier de variables pour Ansible
resource "local_file" "ansible_vars" {
  filename = "${path.module}/group_vars/all.yml"
  content  = yamlencode({
    app_version      = var.app_version
    database_host    = aws_db_instance.main.address
    database_port    = aws_db_instance.main.port
    s3_bucket        = aws_s3_bucket.app_data.id
    aws_region       = var.aws_region
  })
}
```

Utilisation dans Ansible :

```yaml
# site.yml
- name: Configure web servers
  hosts: web
  become: yes
  tasks:
    - name: Install application
      git:
        repo: 'https://github.com/company/app.git'
        dest: /var/www/html
        version: "{{ app_version }}"

    - name: Configure database connection
      template:
        src: db_config.j2
        dest: /etc/app/database.conf
      vars:
        db_host: "{{ database_host }}"
        db_port: "{{ database_port }}"
```

### Approche 4 : Inventaire dynamique Ansible (AWS)

Au lieu de générer un fichier statique, utilisez l'inventaire dynamique AWS d'Ansible :

```bash
# Installer le plugin AWS pour Ansible
pip install boto3

# Créer le fichier de configuration d'inventaire
cat > aws_ec2.yml <<EOF
plugin: aws_ec2
regions:
  - eu-west-3
keyed_groups:
  - key: tags.Role
    prefix: role
  - key: tags.Environment
    prefix: env
hostnames:
  - ip-address
compose:
  ansible_user: "'ec2-user'"
EOF

# Utiliser l'inventaire dynamique
ansible-playbook -i aws_ec2.yml site.yml
```

Ansible interroge directement l'API AWS pour trouver les instances.

### Workflow complet

```bash
# 1. Provisionner l'infrastructure avec Terraform
terraform init
terraform apply

# 2. Attendre que les instances soient prêtes (optionnel)
sleep 30

# 3. Configurer avec Ansible
ansible-playbook -i inventory.ini site.yml

# 4. Vérifier le déploiement
ansible -i inventory.ini web -m ping
ansible -i inventory.ini all -a "systemctl status httpd"
```

### Script d'automatisation complet

```bash
#!/bin/bash
# deploy.sh

set -e  # Arrêter en cas d'erreur

echo "=== Provisioning infrastructure ==="
terraform init
terraform apply -auto-approve

echo "=== Waiting for instances to be ready ==="
sleep 30

echo "=== Running Ansible playbook ==="
ansible-playbook -i inventory.ini site.yml

echo "=== Deployment complete ==="
terraform output
```

### Structure de projet recommandée

```
project/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── inventory.tpl
│   └── terraform.tfvars
├── ansible/
│   ├── site.yml
│   ├── roles/
│   │   ├── webserver/
│   │   └── database/
│   ├── group_vars/
│   │   └── all.yml (généré par Terraform)
│   └── inventory.ini (généré par Terraform)
└── scripts/
    └── deploy.sh
```

### Avantages de l'intégration

- **Terraform** : Infrastructure as Code déclarative, gestion du state, idempotence pour l'infra
- **Ansible** : Configuration management puissante, rôles réutilisables, pas d'agent
- **Ensemble** : Pipeline de déploiement complet de l'infrastructure à l'application

### Points d'attention

- **Ordre de déploiement** : Terraform PUIS Ansible (jamais l'inverse)
- **Clés SSH** : S'assurer que les clés sont disponibles pour Ansible
- **Security groups** : Terraform doit ouvrir le port SSH (22) pour Ansible
- **État des instances** : Attendre que les instances soient vraiment prêtes (pas juste "running")
- **Rollback** : Terraform destroy supprime tout, pensez à sauvegarder les données

### Ressources

- [Ansible AWS Guide](https://docs.ansible.com/ansible/latest/collections/amazon/aws/docsite/guide_aws.html)
- [Dynamic Inventory](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html)
- [Terraform templatefile](https://developer.hashicorp.com/terraform/language/functions/templatefile)

---

## 8. Tests et validation

### Quand utiliser ?

- **Toujours** : Validation de base avant chaque commit
- **CI/CD** : Tests automatisés dans vos pipelines
- **Modules** : Tests complets avant publication
- **Production** : Policy-as-code pour garantir la conformité

### Niveaux de validation

#### 1. Validation syntaxique (niveau 0)

```bash
# Vérifier la syntaxe HCL
terraform fmt -check -recursive

# Valider la configuration
terraform validate

# Dans un pipeline CI
terraform init -backend=false
terraform validate
```

#### 2. Validation des variables (niveau 1)

```hcl
# variables.tf
variable "environment" {
  type        = string
  description = "Environment name"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"

  validation {
    condition     = can(regex("^t[23]\\.", var.instance_type))
    error_message = "Only t2 and t3 instances are allowed for cost optimization."
  }
}

variable "cidr_block" {
  type        = string
  description = "VPC CIDR block"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "Must be a valid IPv4 CIDR block."
  }
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"

  validation {
    condition     = contains(keys(var.tags), "Environment") && contains(keys(var.tags), "Owner")
    error_message = "Tags must include 'Environment' and 'Owner' keys."
  }
}
```

#### 3. Conditions et préconditions (niveau 2)

```hcl
# Précondition sur une ressource
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type

  lifecycle {
    precondition {
      condition     = data.aws_ami.selected.architecture == "x86_64"
      error_message = "The selected AMI must be for x86_64 architecture."
    }

    precondition {
      condition     = var.instance_type != "t2.nano" || var.environment != "prod"
      error_message = "t2.nano instances are not allowed in production."
    }
  }
}

# Postcondition sur une donnée
data "aws_ami" "selected" {
  most_recent = true
  owners      = ["self"]

  lifecycle {
    postcondition {
      condition     = self.state == "available"
      error_message = "The selected AMI is not available."
    }
  }
}
```

#### 4. Checks (Terraform 1.7+) (niveau 3)

```hcl
# Vérifications continues (ne bloquent pas apply)
check "health_check" {
  data "http" "app_health" {
    url = "http://${aws_instance.web.public_ip}/health"
  }

  assert {
    condition     = data.http.app_health.status_code == 200
    error_message = "Application health check failed."
  }
}

check "s3_bucket_encryption" {
  data "aws_s3_bucket" "app_data" {
    bucket = aws_s3_bucket.app_data.id
  }

  assert {
    condition = data.aws_s3_bucket.app_data.server_side_encryption_configuration != null
    error_message = "S3 bucket must have encryption enabled."
  }
}
```

#### 5. Tests automatisés avec terraform test (niveau 4)

Structure de tests :

```
tests/
├── main.tftest.hcl
├── s3_bucket.tftest.hcl
└── security.tftest.hcl
```

Exemple de test :

```hcl
# tests/s3_bucket.tftest.hcl
run "create_bucket" {
  variables {
    bucket_name = "test-bucket-${timestamp()}"
    environment = "dev"
  }

  # Vérifications après apply
  assert {
    condition     = aws_s3_bucket.app_data.bucket != ""
    error_message = "Bucket name is empty"
  }

  assert {
    condition     = aws_s3_bucket.app_data.tags["Environment"] == "dev"
    error_message = "Environment tag not set correctly"
  }
}

run "bucket_versioning" {
  variables {
    bucket_name        = "test-bucket-${timestamp()}"
    enable_versioning  = true
  }

  assert {
    condition = (
      aws_s3_bucket_versioning.app_data[0].versioning_configuration[0].status == "Enabled"
    )
    error_message = "Bucket versioning not enabled"
  }
}
```

Exécution :

```bash
terraform test
```

#### 6. Tests d'intégration avec Terratest (niveau 5)

Terratest est un framework Go pour tester Terraform :

```go
// test/s3_test.go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/gruntwork-io/terratest/modules/aws"
    "github.com/stretchr/testify/assert"
)

func TestS3Bucket(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../",
        Vars: map[string]interface{}{
            "bucket_name": "terratest-bucket-12345",
            "environment": "test",
        },
    })

    // Détruire les ressources à la fin du test
    defer terraform.Destroy(t, terraformOptions)

    // Appliquer la configuration
    terraform.InitAndApply(t, terraformOptions)

    // Récupérer les outputs
    bucketID := terraform.Output(t, terraformOptions, "bucket_id")
    region := "eu-west-3"

    // Vérifications
    assert.NotEmpty(t, bucketID)
    aws.AssertS3BucketExists(t, region, bucketID)

    // Vérifier le versioning
    versioning := aws.GetS3BucketVersioning(t, region, bucketID)
    assert.Equal(t, "Enabled", versioning)
}
```

Exécution :

```bash
cd test
go test -v -timeout 30m
```

### Policy-as-Code avec OPA (Open Policy Agent)

Définir des règles de conformité :

```rego
# policies/s3_encryption.rego
package terraform.s3

deny[msg] {
    resource := input.resource.aws_s3_bucket[_]
    not resource.server_side_encryption_configuration

    msg := sprintf("S3 bucket '%s' must have encryption enabled", [resource.bucket])
}

deny[msg] {
    resource := input.resource.aws_s3_bucket[_]
    resource.acl == "public-read"

    msg := sprintf("S3 bucket '%s' must not be public", [resource.bucket])
}
```

Validation avec Conftest :

```bash
# Générer le plan en JSON
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json

# Valider avec OPA
conftest test tfplan.json -p policies/
```

### Pipeline CI/CD complet

```yaml
# .github/workflows/terraform.yml
name: Terraform CI

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: hashicorp/setup-terraform@v2

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Init
        run: terraform init -backend=false

      - name: Terraform Validate
        run: terraform validate

      - name: Run Terraform Tests
        run: terraform test

      - name: Generate Plan
        run: |
          terraform plan -out=tfplan
          terraform show -json tfplan > tfplan.json

      - name: Policy Validation
        uses: instrumenta/conftest-action@v0.4.0
        with:
          files: tfplan.json
          policy: policies/
```

### Pre-commit hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
      - id: terraform_tflint
      - id: terraform_checkov
```

Installation :

```bash
pip install pre-commit
pre-commit install
pre-commit run -a  # Exécuter sur tous les fichiers
```

### Checklist de validation

Avant chaque commit :
- [ ] `terraform fmt` - Code formaté
- [ ] `terraform validate` - Syntaxe valide
- [ ] Validations de variables configurées
- [ ] Valeurs sensibles marquées comme `sensitive`
- [ ] Documentation à jour

Avant chaque merge :
- [ ] `terraform test` - Tests passent
- [ ] `terraform plan` - Pas de changements inattendus
- [ ] Policy checks passent
- [ ] Code review effectuée

Avant chaque release :
- [ ] Tests d'intégration (Terratest) passent
- [ ] Tests dans un environnement de staging
- [ ] Documentation externe mise à jour
- [ ] Changelog mis à jour

### Outils utiles

| Outil              | Usage              | Installation            |
| ------------------ | ------------------ | ----------------------- |
| terraform fmt      | Formatage          | Intégré                 |
| terraform validate | Validation syntaxe | Intégré                 |
| terraform test     | Tests natifs       | Terraform 1.6+          |
| tflint             | Linter avancé      | `brew install tflint`   |
| checkov            | Scan de sécurité   | `pip install checkov`   |
| tfsec              | Scan de sécurité   | `brew install tfsec`    |
| terratest          | Tests Go           | `go get`                |
| conftest           | Policy-as-code     | `brew install conftest` |

### Ressources

- [Terraform Test](https://developer.hashicorp.com/terraform/language/tests)
- [Custom Conditions](https://developer.hashicorp.com/terraform/language/expressions/custom-conditions)
- [Terratest](https://terratest.gruntwork.io/)
- [Conftest](https://www.conftest.dev/)
- [Pre-commit Terraform](https://github.com/antonbabenko/pre-commit-terraform)

---

## 9. Outils complémentaires pour Terraform

### Outils de validation et sécurité

Au-delà de `terraform validate`, plusieurs outils open source permettent d'analyser votre code Terraform :

| Outil         | Description                                                        | Installation             |
| ------------- | ------------------------------------------------------------------ | ------------------------ |
| **tflint**    | Linter pour détecter les erreurs et appliquer les bonnes pratiques | `brew install tflint`    |
| **checkov**   | Scanner de sécurité pour détecter les mauvaises configurations     | `pip install checkov`    |
| **tfsec**     | Analyse de sécurité statique spécialisée pour Terraform            | `brew install tfsec`     |
| **terrascan** | Scanner de sécurité et conformité pour l'IaC                       | `brew install terrascan` |
| **infracost** | Estimation des coûts de votre infrastructure AWS                   | `brew install infracost` |

### Utilisation typique

```bash
# Linter - bonnes pratiques
tflint --init
tflint

# Sécurité - analyse des vulnérabilités
checkov -d .
tfsec .
terrascan scan -t aws

# Coûts - estimation des dépenses
infracost breakdown --path .
```

### Quand les utiliser ?

- **En développement** : `tflint` pour corriger les erreurs rapidement
- **Avant commit** : `checkov` ou `tfsec` pour vérifier la sécurité
- **En CI/CD** : Tous les outils pour validation complète
- **Avant production** : `infracost` pour estimer le budget

### Ressources

- [tflint](https://github.com/terraform-linters/tflint)
- [checkov](https://www.checkov.io/)
- [tfsec](https://github.com/aquasecurity/tfsec)
- [terrascan](https://runterrascan.io/)
- [infracost](https://www.infracost.io/)

---

## Conclusion

Ces sujets avancés vous permettront de construire des infrastructures robustes, maintenables et collaboratives avec Terraform.

### Par où commencer ?

Si vous avez du temps libre, explorez dans cet ordre :

1. **Modules** - Réutilisabilité et organisation
2. **Remote State** - Essentiel pour le travail en équipe
3. **Structures de données complexes et fonctions** - Pour manipuler des configurations avancées
4. **Tests et validation** - Qualité et fiabilité
5. **Workspaces** - Gestion multi-environnement

### Ressources générales

- [Documentation officielle Terraform](https://developer.hashicorp.com/terraform)
- [Terraform Registry](https://registry.terraform.io/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Awesome Terraform](https://github.com/shuaibiyy/awesome-terraform)

### Communauté

- [Terraform Discuss](https://discuss.hashicorp.com/c/terraform-core)
- [HashiCorp Learn](https://learn.hashicorp.com/terraform)
- [r/Terraform](https://www.reddit.com/r/Terraform/)

Bon apprentissage !
