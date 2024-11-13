# create azure infrastructure with terraform

## overview

Create Azure infrastructure with Terraform for the blog post sample.

## After checkout this repo

Create storrage for Terraform state file

```bash
az login --use-device-code
az account set --subscription "Your Subscription Name"

az group create \
    --name iiot-euw-terraform-rg \
    --location switzerlandnorth

az storage account create \
    --name iioteuwterraform \
    --resource-group iiot-euw-terraform-rg \
    --location switzerlandnorth \
    --sku Standard_ZRS 

az storage container create \
    --account-name iioteuwterraform \
    --name tfstate

# Terraform initialization
terraform init 

# Creat the infrastructure
terraform apply --auto-approve
```

## Cleanup

```bash
terraform apply -destroy --auto-approve
```


## Own Client certificate

If you don't already have a certificate, or you do not like the one in the folder `/terraform/certs`, you can create a sample certificate by using the [step CLI](https://smallstep.com/docs/step-cli/installation/). Consider installing manually for Windows.

```bash
# set the working path
export STEPPATH=./certs

# To create root and intermediate certificates, run the following command. Remember the password, which you need to use in the next step. (It could be ICVrwXQ10UVc6AIe6KTSYDkQV893BZ5u)
step ca init --deployment-type standalone --name iiotca --dns localhost --address 127.0.0.1:443 --provisioner iiot

# Use the certificate authority (CA) files generated to create a certificate for the client. Make sure to use the correct path for the cert and secrets files in the command.
step certificate create edge01 certs/edge01.pem certs/edge01.key --ca ./certs/certs/intermediate_ca.crt --ca-key ./certs/secrets/intermediate_ca_key --no-password --insecure --not-after 2400h

# To view the thumbprint, run the step command.
step certificate fingerprint certs/edge01.pem
```

Now update the clients Thumbprint in allowedThumbprints of `iiot.tf`

# Event Grid Explorer

Use the Service Bus Explorer in the latest version to explore the Event Grid Topic. See [here](https://github.com/paolosalvatori/ServiceBusExplorer/blob/main/EventGridExplorer_README.md).

## MQTT Client connection settings

**MQTT Explorer**

![](assets/mqttexplorer.drawio.png)