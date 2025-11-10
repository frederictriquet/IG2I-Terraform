# Exercice 1 : Comprendre le state Terraform avec le provider Random

## Objectifs pédagogiques

- Découvrir la syntaxe de base de Terraform
- Comprendre le concept de **state** (état) dans Terraform
- Observer comment Terraform gère les ressources entre différentes exécutions
- Manipuler un provider simple qui ne nécessite pas de credentials cloud

## Contexte

Le provider `random` de Terraform permet de générer des valeurs aléatoires (noms, nombres, mots de passe, etc.). Il ne nécessite aucune configuration d'infrastructure cloud et permet de se concentrer sur les mécanismes fondamentaux de Terraform.

## Instructions

### Partie 1 : Première configuration

1. Dans le dossier `exercise-01/`, créez un fichier `main.tf`

2. Configurez le provider random :
```hcl
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
```

Sa documentation se trouve ici : https://registry.terraform.io/providers/hashicorp/random/latest/docs (les notions de `keepers` et de `ephemeral resources` ne sont pas utiles pour nous).

3. Créez les ressources suivantes :
   - Un `random_pet` qui génère un nom de serveur (2 mots séparés par un tiret)
   - Un `random_integer` qui génère un numéro de port entre 8000 et 8999
   - Un `random_password` de 16 caractères avec des caractères spéciaux
   - Un `random_uuid` pour un identifiant de session

4. Ajoutez des outputs pour afficher toutes ces valeurs générées (attention : marquez le password comme `sensitive`)

### Partie 2 : Découverte du workflow Terraform

1. Initialisez Terraform :
```bash
terraform init
```
   - Observez les fichiers créés
   - Que fait cette commande ?

2. Visualisez le plan d'exécution :
```bash
terraform plan
```
   - Que signifie le symbole `+` ?
   - Combien de ressources seront créées ?

3. Appliquez la configuration :
```bash
terraform apply
```
   - Confirmez avec `yes`
   - Notez les valeurs générées

4. Examinez le fichier `terraform.tfstate` :
   - Quel est son format ?
   - Quelles informations contient-il ?
   - Retrouvez-vous les valeurs générées ?

### Partie 3 : Comprendre l'immutabilité du state

1. Exécutez à nouveau :
```bash
terraform plan
```
   - Que constatez-vous ?
   - Pourquoi Terraform ne veut-il rien modifier ?

2. Exécutez :
```bash
terraform apply
```
   - Les valeurs aléatoires ont-elles changé ?
   - Pourquoi ?

3. Affichez les outputs sans réappliquer :
```bash
terraform output
```
   - Pour voir le password : `terraform output password`

### Partie 4 : Forcer la régénération

1. Marquez une ressource pour être recréée :
```bash
terraform taint random_pet.server_name
```

2. Exécutez un plan :
```bash
terraform plan
```
   - Que signifient les symboles `-/+` ?
   - Que va-t-il se passer ?

3. Appliquez les changements :
```bash
terraform apply
```
   - Le nom du serveur a-t-il changé ?
   - Les autres valeurs ont-elles changé ?

### Partie 5 : Modifier la configuration

1. Modifiez votre `random_pet` pour utiliser 3 mots au lieu de 2 :
```hcl
resource "random_pet" "server_name" {
  length    = 3
  separator = "-"
}
```

2. Exécutez un plan et observez ce que Terraform prévoit de faire

3. Appliquez les changements

### Partie 6 : Destruction

1. Détruisez toutes les ressources :
```bash
terraform destroy
```

2. Examinez le fichier `terraform.tfstate` après la destruction
   - Est-il vide ?
   - Que contient-il ?

## Questions de réflexion

1. **Pourquoi le state est-il important ?**
   - Que se passerait-il si Terraform n'avait pas de state ?

2. **Immutabilité des valeurs aléatoires**
   - Pourquoi est-ce important que les valeurs aléatoires ne changent pas à chaque `terraform apply` ?
   - Dans quels cas réels cela pourrait-il poser problème si elles changeaient ?

3. **State en équipe**
   - Le fichier `terraform.tfstate` peut-il être partagé sur Git ?
   - Quels problèmes cela pourrait-il causer dans une équipe ?

4. **Comparaison avec Ansible**
   - En quoi la gestion de l'état de Terraform diffère-t-elle d'Ansible ?
   - Quels sont les avantages et inconvénients de chaque approche ?

## Pour aller plus loin

- Explorez les autres ressources du provider random : `random_string`, `random_shuffle`, `random_id`
- Lisez la documentation sur le [remote state](https://developer.hashicorp.com/terraform/language/state/remote)
- Découvrez les [backends](https://developer.hashicorp.com/terraform/language/settings/backends/configuration) Terraform
