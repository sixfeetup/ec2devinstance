#!/bin/bash

wait_lb() {
while true
do
  curl --output /dev/null --silent -k "https://${k3s_url}:6443"
  if [[ "$?" -eq 0 ]]; then
    break
  fi
  sleep 5
  echo "wait for LB"
done
}

render_traefik_config(){
cat << 'EOF' > "$TRAEFIK_CONFIG"
--
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    additionalArguments:
    - "--log.level=DEBUG"
    - "--certificatesresolvers.letsencrypt.acme.email=roche@sixfeetup.com"
    - "--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json"
    - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
EOF
}

render_staging_issuer(){
STAGING_ISSUER_RESOURCE=$1
cat << 'EOF' > "$STAGING_ISSUER_RESOURCE"
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
 name: letsencrypt-staging
 namespace: cert-manager
spec:
 acme:
   # The ACME server URL
   server: https://acme-staging-v02.api.letsencrypt.org/directory
   # Email address used for ACME registration
   email: ${certmanager_email_address}
   # Name of a secret used to store the ACME account private key
   privateKeySecretRef:
     name: letsencrypt-staging
   # Enable the HTTP-01 challenge provider
   solvers:
   - http01:
       ingress:
         class:  traefik
EOF
}

render_prod_issuer(){
PROD_ISSUER_RESOURCE=$1
cat << 'EOF' > "$PROD_ISSUER_RESOURCE"
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
  namespace: cert-manager
spec:
  acme:
    # The ACME server URL
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: ${certmanager_email_address}
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod
    # Enable the HTTP-01 challenge provider
    solvers:
    - http01:
        ingress:
          class: traefik
EOF
}

apt-get update
apt-get install -y software-properties-common unzip git nfs-common jq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

echo "Cluster init!"
until (curl -sfL https://get.k3s.io | sh -s - --cluster-init --tls-san ${k3s_url} --tls-san ${k3s_tls_san}); do
  echo 'k3s did not install correctly'
  sleep 2
done

until kubectl get pods -A | grep 'Running'; do
  echo 'Waiting for k3s startup'
  sleep 5
done

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml

# Wait cert-manager to be ready
until kubectl get pods -n cert-manager | grep 'Running'; do
  echo 'Waiting for cert-manager to be ready'
  sleep 15
done

render_staging_issuer /root/staging_issuer.yaml
render_prod_issuer /root/prod_issuer.yaml

kubectl create -f /root/prod_issuer.yaml
kubectl create -f /root/staging_issuer.yaml

cp /etc/rancher/k3s/k3s.yaml /root/kubeconfig.yaml
sed -i 's/127.0.0.1/${k3s_url}/' /root/kubeconfig.yaml
sed -i 's/default/ec2dev-cluster/' /root/kubeconfig.yaml
aws secretsmanager update-secret --secret-id ec2dev-kubeconfig --secret-string file:///root/kubeconfig.yaml
