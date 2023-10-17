terraform.tfvars: MY_IP :=  $(shell curl -s checkip.amazonaws.com)
terraform.tfvars:
	cat terraform.tfvars.template | sed s/{admin_ip}/$(MY_IP)/ > terraform.tfvars

ec2dev_key:
	ssh-keygen -t ED25519 -f ./ec2dev_key -N ""

tfplan.out: terraform.tfvars ec2dev_key
	terraform init
	terraform plan -out=tfplan.out

deploy: tfplan.out
	terraform apply tfplan.out

INSTANCE_IP := $(shell terraform output -raw instance_ip)

instance-ip: # ec2 instance ip
	@echo $(shell terraform output -raw instance_ip)

config:
	aws secretsmanager get-secret-value --secret-id ec2dev-kubeconfig | jq -r '.SecretString' > ./kubeconfig
	# backing up the old kubeconfig
	cp ~/.kube/config ~/.kube/config.bak
	K3S_CONTEXT=`kubectl --kubeconfig=kubeconfig config view -o=jsonpath='{.contexts[0].name}'`
	# Extracting the cluster, context, and user information from kubeconfig
	kubectl --kubeconfig=./kubeconfig config view --raw > tmp_k3s.yaml
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
	ssh -i ./ec2dev_key ubuntu@$(INSTANCE_IP)

destroy:
	terraform destroy
	rm tfplan.out
	# force delete the secret in order to reuse the secret id when 
	# recreating the cluster
	aws secretsmanager delete-secret --secret-id ec2dev-kubeconfig --force-delete-without-recovery

kubecreds:
	aws sso login
	aws ecr get-login-password | docker login --username AWS \
		--password-stdin $(ECR_REPO)
	kubectl delete secret regcred --ignore-not-found
	kubectl create secret docker-registry regcred \
		--docker-server=$(ECR_REPO)\
		--docker-username=AWS \
		--docker-password=$(shell aws ecr get-login-password)

clean:
	rm -f terraform.tfvars
	rm -f tfplan.out

admin-ip: MY_IP :=  $(shell curl -s checkip.amazonaws.com)
admin-ip: clean terraform.tfvars # update admin ip
	terraform plan -out=tfplan.out
	terraform apply tfplan.out
