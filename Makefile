terraform.tfvars: MY_IP :=  $(shell curl -s checkip.amazonaws.com)
terraform.tfvars:
	cat terraform.tfvars.template | sed s/{admin_ip}/$(MY_IP)/ > terraform.tfvars

key-pair:
	ssh-keygen -t ED25519 -f ~/.ssh/ec2dev_key -N ""

tfplan.out: terraform.tfvars key-pair
	terraform plan -out=tfplan.out

deploy: tfplan.out
	terraform apply tfplan.out

INSTANCE_IP := $(shell terraform output -raw instance_ip)

instance-ip: # ec2 instance ip
	@echo $(shell terraform output -raw instance_ip)

config:
	ssh -oStrictHostKeyChecking=no -i ~/.ssh/ec2dev_key \
		ubuntu@$(INSTANCE_IP) \
		'curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--tls-san $(INSTANCE_IP)" K3S_KUBECONFIG_MODE="644" sh -s -'
	ssh -oStrictHostKeyChecking=no -i ~/.ssh/ec2dev_key \
		ubuntu@$(INSTANCE_IP) cat /etc/rancher/k3s/k3s.yaml \
		> /tmp/kubeconfig
	sed -i 's/127.0.0.1/$(INSTANCE_IP)/' /tmp/kubeconfig
	sed -i 's/default/ec2dev-cluster/' /tmp/kubeconfig
	cat /tmp/kubeconfig >> ~/.kube/config
	kubectl config use-context ec2dev-cluster

context:
	kubectl config use-context ec2dev-cluster

ssh:
	ssh -i ~/.ssh/ec2dev_key ubuntu@$(INSTANCE_IP)

destroy:
	terraform destroy

kubecreds:
	aws sso login
	aws ecr get-login-password --region us-east-1 | docker login --username AWS \
		--password-stdin $(ECR_REPO)
	kubectl delete secret regcred --ignore-not-found
	kubectl create secret docker-registry regcred \
		--docker-server=$(ECR_REPO)\
		--docker-username=AWS \
		--docker-password=$(shell aws ecr get-login-password)

clean:
	rm terraform.tfvars
