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

## Terraform init

```
terraform init
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
