# Terraform Training Repository - IG2I

This repository contains progressive exercises teaching Infrastructure as Code concepts with Terraform, designed for IG2I students.

## Course Presentation

View the course slides online: [Terraform Introduction Course](https://frederictriquet.github.io/IG2I-Terraform/)

PDF version: [cours-slides.pdf](https://frederictriquet.github.io/IG2I-Terraform/cours-slides.pdf)

## Exercises

The exercises build progressively on each other. Complete them in order:

* Exercise 00: Environment setup on Red Hat with Terraform, VSCode, and AWS credentials
* Exercise 01: State management fundamentals using the random provider (no cloud needed)
* Exercise 02: First real AWS deployment with S3 buckets, authentication, and tagging
* Exercise 03: Variables, types, validation, and file organization
* Exercise 04: Locals for computed values, DRY principle, and merge function

## More Exercises (Ideas for Future Development)

The following exercises would extend the training with more advanced Terraform concepts:

### Exercise 05 - Outputs and Data Sources
**Purpose:** Learn to extract information from existing infrastructure and share data between Terraform configurations.

Build on the previous exercises by adding output values that can be consumed by other modules or projects. Introduce data sources to query existing AWS resources (e.g., AMIs, availability zones). Practice using outputs to display important infrastructure information like bucket URLs, ARNs, and resource IDs. Understand the difference between creating resources and querying existing ones.

**Key concepts:** `output` blocks with sensitive flags, `data` sources for reading existing resources, cross-project references, terraform_remote_state data source.

### Exercise 06 - Count and For-Each for Multiple Resources
**Purpose:** Master resource iteration to create multiple similar resources efficiently.

Learn to use `count` to create multiple instances of the same resource (e.g., 3 S3 buckets). Compare with `for_each` for creating resources from a map or set with different configurations. Understand when to use count vs for_each, and how to reference individual resources in collections. Practice creating dynamic, scalable infrastructure.

**Key concepts:** `count` parameter, `count.index`, `for_each` with maps and sets, `each.key` and `each.value`, resource addressing with indices.

### Exercise 07 - Conditional Resources and Dynamic Blocks
**Purpose:** Create flexible infrastructure that adapts based on input variables.

Implement conditional resource creation using count and boolean variables (e.g., enable versioning only in production). Use dynamic blocks to conditionally add configuration blocks within resources (like S3 lifecycle rules or CORS configuration). Learn to write expressive infrastructure code that handles multiple scenarios without duplication.

**Key concepts:** Conditional expressions `condition ? true_val : false_val`, `count` with ternary operators, `dynamic` blocks, complex conditionals.

### Exercise 08 - Modules for Reusable Infrastructure
**Purpose:** Create reusable, composable infrastructure components.

Extract common patterns from previous exercises into a reusable S3 bucket module. Learn module structure (inputs, outputs, resources), how to call modules with different configurations, and module versioning. Understand the benefits of modules for consistency, testing, and team collaboration. Practice creating both simple and complex module interfaces.

**Key concepts:** Module directory structure, `module` blocks, passing variables to modules, module outputs, local vs remote modules, module composition.

### Exercise 09 - Remote State with S3 Backend
**Purpose:** Enable team collaboration by storing Terraform state in a shared location.

Configure Terraform to use S3 as a backend for storing state files instead of local storage. Set up state locking with DynamoDB to prevent concurrent modifications. Understand the security implications of remote state and how to encrypt state at rest. Practice state migration from local to remote backend.

**Key concepts:** Backend configuration, S3 backend with encryption, DynamoDB for state locking, state migration, partial backend configuration.

### Exercise 10 - Terraform Workspaces for Multiple Environments
**Purpose:** Manage multiple environments (dev, staging, production) with a single configuration.

Use Terraform workspaces to maintain separate state files for different environments while using the same code. Learn to reference the current workspace name in configurations to customize behavior per environment. Understand workspace limitations and when to use them versus separate directories or modules.

**Key concepts:** `terraform workspace` commands, `terraform.workspace` variable, workspace-specific variables, workspace best practices.

### Exercise 11 - Complex Data Structures and Functions
**Purpose:** Master Terraform's expression language for advanced use cases.

Work with complex variable types (lists of objects, maps of maps). Use built-in functions for string manipulation (`join`, `split`, `replace`), collection operations (`merge`, `concat`, `flatten`), and type conversions. Practice using `for` expressions to transform data structures. Build conditional logic with `lookup`, `coalesce`, and `try` functions.

**Key concepts:** List and map operations, `for` expressions, `lookup()`, `merge()`, `flatten()`, `can()` and `try()` for error handling, string interpolation and templates.

### Exercise 12 - Importing Existing Infrastructure
**Purpose:** Learn to bring existing AWS resources under Terraform management.

Practice using `terraform import` to bring manually-created AWS resources into Terraform state. Write Terraform configurations that match existing infrastructure. Understand the import process, its limitations, and when it's appropriate. Learn to generate configuration from existing resources using tools like `terraformer`.

**Key concepts:** `terraform import` command, resource addressing, writing configurations to match existing resources, import blocks (Terraform 1.5+), state manipulation.

### Exercise 13 - Provisioners and Local-Exec
**Purpose:** Execute scripts and commands during resource creation (with caveats).

Learn when and how to use provisioners for tasks that can't be accomplished with native resources. Use `local-exec` to run commands on your local machine and `remote-exec` for remote servers. Understand why provisioners should be a last resort and alternatives to consider. Practice error handling with provisioner failures.

**Key concepts:** `provisioner` blocks, `local-exec`, `remote-exec`, provisioner timing (creation/destruction), when_condition, null_resource for standalone provisioners.

### Exercise 14 - Integration with Ansible and Configuration Management
**Purpose:** Combine Terraform's infrastructure provisioning with Ansible's configuration management.

Use Terraform to create EC2 instances and generate an Ansible inventory dynamically. Pass outputs from Terraform (like IP addresses and SSH keys) to Ansible playbooks. Understand the separation of concerns between infrastructure (Terraform) and configuration (Ansible). Automate the full deployment pipeline from infrastructure to application.

**Key concepts:** Dynamic inventory generation, local-exec to trigger Ansible, template files for inventory, null_resource dependencies, integration patterns.

### Exercise 15 - Terraform Testing and Validation
**Purpose:** Implement testing strategies to ensure infrastructure quality.

Write validation rules in variables to catch errors early. Use `terraform validate` and `terraform plan` in CI/CD pipelines. Introduce `terraform test` (experimental) for writing automated tests. Learn about tools like `terratest` for integration testing. Practice pre-commit hooks and policy-as-code with Sentinel or OPA.

**Key concepts:** Variable validation, custom conditions, `terraform test`, integration with CI/CD, policy-as-code, pre-commit hooks, automated testing strategies.
