# k3s on AWS ec2

Deploy an AWS ec2 instance with a k3s cluster installed.

## Prerequisites

aws cli and terraform

## Login to AWS

Create a SFU profile for your own sandboxed AWS environment and add it to `~/.aws/config` eg:

```
[profile my-sfu-sandbox]
sso_start_url = https://sixfeetup.awsapps.com/start
sso_region = us-east-1
sso_account_id = 000000000000
sso_role_name = admin
region = us-east-1
output = json
```

Switch to your profile and log in:

```
export AWS_PROFILE=my-sfu-sandbox
aws sso login
```

## Deploy k3s instance on AWS

```
make deploy
```

## Add k3s cluster config

Once your ec2 instance is up and running, you can run `make config` to add the cluster to your local Kubernetes configuration. This will install k3s on the ec2instance and add the kubeconfig to `~/.kube/config`.

Check that the new cluster is listed:

```
kubectl config get-contexts
```

## Credentials

In order for Skaffold or Tilt to push images and Kubernetes to pull images, we
need to authenticate against an image repository.

```
export ECR_REPO=xxxxxxxxx.dkr.ecr.us-east-1.amazonaws.com
aws sso login
make kubecreds
```

## Debugging

The `admin` security group will restrict access to the instance from your IP only, so if your IP address changes or if you change from on/off a VPN you will not be able to access the cluster anymore. The IP is set in `terraform.tfvars:admin_ip`.

To update the security group to use your current IP run:
```
make admin-ip
```

If you're using a different AWS region than the repo default of `us-east-1`, remember to update it in `terraform.tfvars` and make sure your AWS config file matches it.
If you are using a different AWS profile than the default one you will need to update the makefile to explictly use that profile, eg:

```
kubecreds:
    aws sso login --profile my-custom-profile
```

If you want to run multiple ec2 cluster instances on the same account, for instance sandbox and prod instances, you will have to change the resource names to prevent conflicts.

To clean everything and start again run:
```
make destroy
```