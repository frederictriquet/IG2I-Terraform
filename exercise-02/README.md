# Exercice 2 : Premier déploiement sur AWS avec S3

## Objectifs pédagogiques

- Configurer l'authentification AWS pour Terraform
- Déployer sa première ressource cloud réelle sur AWS
- Comprendre l'importance des noms de ressources globalement uniques
- Découvrir la gestion des tags pour organiser les ressources
- Observer les différences entre le provider random et un provider cloud

## Prérequis

<!-- ### 1. Compte AWS -->

 <!-- Deux options : -->

<!-- **Option A : AWS Academy (recommandée pour les étudiants)** -->
- Connectez-vous à AWS Academy
- Lancez votre Learner Lab
- Cliquez sur "AWS Details" puis "Show" à côté de "AWS CLI"
- Copiez les credentials (aws_access_key_id, aws_secret_access_key, aws_session_token)

<!-- **Option B : Compte AWS personnel**
- Créez un utilisateur IAM avec les permissions S3
- Générez des access keys pour ce compte -->
<!-- 
### 2. Configuration des credentials AWS

Créez le fichier `~/.aws/credentials` :

```ini
[default]
aws_access_key_id = VOTRE_ACCESS_KEY
aws_secret_access_key = VOTRE_SECRET_KEY
aws_session_token = VOTRE_TOKEN  # Seulement pour AWS Academy
```

Créez le fichier `~/.aws/config` :

```ini
[default]
region = eu-west-3
output = json
```

### 3. Vérification -->

Testez votre configuration :

```bash
aws s3 ls
```

Si la commande fonctionne sans erreur, vous êtes prêt !

## Contexte

Amazon S3 (Simple Storage Service) est le service de stockage objet d'AWS. C'est l'une des ressources AWS les plus simples à créer avec Terraform car elle ne nécessite pas de configuration réseau complexe.

**Point important** : Les noms de buckets S3 doivent être **globalement uniques** dans toute l'infrastructure AWS mondiale. C'est pourquoi nous utiliserons le provider `random` pour générer un suffixe unique.

## Instructions

### Partie 1 : Configuration de base

1. Dans le dossier `exercise-02/`, créez un fichier `main.tf`

2. Configurez les providers nécessaires :
   - Le provider AWS (https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
   - Le provider random (comme dans l'exercice précédent)

3. Configurez le provider AWS pour utiliser la région `eu-west-3` (Paris) ou la même région que l'EC2 qui vous sert de passerelle.

4. Créez une ressource `random_id` avec `byte_length = 4` pour générer un suffixe

### Partie 2 : Création du bucket S3

1. Créez une ressource `aws_s3_bucket` :
   - Utilisez un nom de bucket qui combine un préfixe de votre choix avec le suffixe aléatoire
   - Exemple : `"mon-bucket-terraform-${random_id.suffix.hex}"`
   - Ajoutez des tags pertinents (Name, Environment, ManagedBy)

2. Ajoutez un output pour afficher le nom du bucket créé

3. Initialisez et appliquez :
```bash
terraform init
terraform plan
terraform apply
```

4. Vérifiez dans la console AWS ou via la CLI que votre bucket existe :
```bash
aws s3 ls | grep terraform
```

### Partie 3 : Configuration avancée du bucket

1. Activez le versioning sur votre bucket en ajoutant une ressource `aws_s3_bucket_versioning` :
```hcl
resource "aws_s3_bucket_versioning" "my_bucket_versioning" {
  bucket = aws_s3_bucket.VOTRE_BUCKET.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

2. Ajoutez le chiffrement par défaut avec une ressource `aws_s3_bucket_server_side_encryption_configuration` :
```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.VOTRE_BUCKET.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

3. Appliquez les changements :
```bash
terraform plan
terraform apply
```

4. Observez que Terraform ne recrée pas le bucket, il le modifie (symbole `~` dans le plan)

### Partie 4 : Ajouter des outputs

Ajoutez des outputs pour afficher :
- Le nom du bucket
- L'ARN du bucket (Amazon Resource Name)
- La région du bucket

Affichez les outputs :
```bash
terraform output
```

### Partie 5 : Tester l'upload d'un fichier

0. Lisez l'aide de la commande `output` :
```bash
terraform output -help
```

1. Créez un fichier de test local :
```bash
echo "Hello from Terraform!" > test.txt
```

1. Uploadez-le dans votre bucket :
```bash
aws s3 cp test.txt s3://$(terraform output -raw bucket_name)/
```

1. Listez le contenu de votre bucket :
```bash
aws s3 ls s3://$(terraform output -raw bucket_name)/
```

1. Téléchargez le fichier pour vérifier :
```bash
aws s3 cp s3://$(terraform output -raw bucket_name)/test.txt downloaded.txt
cat downloaded.txt
```

### Partie 6 : Observer le state

1. Examinez votre `terraform.tfstate` :
   - Combien de ressources sont trackées ?
   - Trouvez les métadonnées AWS (ARN, region, etc.)
   - Comparez avec l'exercice 1 : quelles différences ?

2. Affichez le state de manière lisible :
```bash
terraform show
```

### Partie 7 : Destruction

1. Avant de détruire, le bucket doit être vide. Supprimez le fichier test :
```bash
aws s3 rm s3://$(terraform output -raw bucket_name)/test.txt
```

2. Détruisez toutes les ressources :
```bash
terraform destroy
```

3. Vérifiez que le bucket n'existe plus :
```bash
aws s3 ls | grep terraform
```

## Questions de réflexion

1. **Unicité globale des noms**
   - Pourquoi les buckets S3 doivent-ils avoir des noms globalement uniques ?
   - Que se passerait-il si vous réutilisiez le même nom de bucket ?
   - Pourquoi utiliser `random_id` au lieu de `random_pet` pour ce cas ?

2. **Dépendances implicites**
   - Terraform a-t-il créé les ressources dans un ordre particulier ?
   - Comment Terraform sait-il que `aws_s3_bucket_versioning` dépend du bucket ?
   - Regardez dans le state : voyez-vous les dépendances ?

3. **State et ressources cloud**
   - Que contient le state pour une ressource AWS comparé à une ressource random ?
   - Pourquoi le state contient-il l'ARN et d'autres métadonnées AWS ?
   - Que se passerait-il si vous supprimiez manuellement le bucket dans la console AWS puis exécutiez `terraform plan` ?

4. **Ressources AWS vs Ressources Random**
   - Quelle est la différence fondamentale entre créer une ressource `random_*` et une ressource `aws_*` ?
   - Laquelle est plus "risquée" à manipuler ? Pourquoi ?

5. **Tags et organisation**
   - À quoi servent les tags dans AWS ?
   - Comment pourriez-vous utiliser les tags pour organiser des ressources créées par différents projets Terraform ?
   - Comment retrouver toutes les ressources avec le tag `ManagedBy = "Terraform"` dans AWS ?

## Problèmes courants

### Erreur : "BucketAlreadyExists"
Le nom de bucket est déjà utilisé (par vous ou quelqu'un d'autre dans le monde). Changez le préfixe ou recréez le random_id.

### Erreur : "AccessDenied"
Vos credentials AWS n'ont pas les permissions nécessaires. Vérifiez vos policies IAM.

### Erreur : "AWS credentials not found"
Vérifiez votre fichier `~/.aws/credentials` ou vos variables d'environnement.

### Erreur lors du destroy : "BucketNotEmpty"
Vous devez vider le bucket avant de le détruire. Utilisez `aws s3 rm --recursive`.

