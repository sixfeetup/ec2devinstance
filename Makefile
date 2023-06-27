terraform.tfvars: MY_IP :=  $(shell curl -s checkip.amazonaws.com)
terraform.tfvars:
	cat terraform.tfvars.template | sed s/{admin_ip}/$(MY_IP)/ > terraform.tfvars

key-pair:
	ssh-keygen -t ED25519 -f ~/.ssh/ec2dev_key -N ""

tfplan.out: terraform.tfvars key-pair
	terraform init
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
		> kubeconfig
	sed -i 's/127.0.0.1/$(INSTANCE_IP)/' kubeconfig
	sed -i 's/default/ec2dev-cluster/' kubeconfig
	# backing up the old kubeconfig
	cp ~/.kube/config ~/.kube/config.bak
	K3S_CONTEXT=`kubectl --kubeconfig=kubeconfig config view -o=jsonpath='{.contexts[0].name}'`
	# Extracting the cluster, context, and user information from kubeconfig
	kubectl --kubeconfig=./kubeconfig config view --raw --minify > tmp_k3s.yaml
	# Removing the old information from ~/.kube/config
	kubectl config unset contexts.${K3S_CONTEXT}
	kubectl config unset clusters.${K3S_CONTEXT}
	kubectl config unset users.${K3S_CONTEXT}
	# Adding the new information to ~/.kube/config
	KUBECONFIG=tmp_k3s.yaml:~/.kube/config kubectl config view --flatten > tmp_config
	mv tmp_config ~/.kube/config
	rm tmp_k3s.yaml kubeconfig
	@echo "Updated ~/.kube/config with ec2dev-cluster details."
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
