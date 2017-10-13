# A Simple Automate Cluster Terraform Implementation

This creates the following:
 * Chef Server
 * Automate Server
 * Workflow Runner

All with the latest stable releases.

In order to keep things super consistent, stable, simple and fast, no cookbooks are used, just one shell script that fetches from downloads.chef.io

It just works, every time.

A local `.chef/knife.rb` is configured for you to start communicating to the Chef Server quickly.

# Quickstart

1. Review and update `variables.tf`
2. Copy a Chef Automate license file into this directory and name it `delivery.license`
3. run `terraform plan` to see what it will do
4. run `terraform apply` to build the infrastructure
5. run `knife ...` to begin communicating with the Chef Server
6. run `terraform destroy` to tear everything down
