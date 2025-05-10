#!/bin/bash
# setup.sh - Script to set up the GKE environment and deploy the Online Boutique app

# Exit on error
set -e

echo "==== Setting up GKE environment for Log Analytics Demo ===="

# Set zone
echo "Setting compute zone to europe-west1-b..."
gcloud config set compute/zone europe-west1-b

# Check cluster status
echo "Checking GKE cluster status..."
gcloud container clusters list
echo "Waiting for cluster to be ready..."
until gcloud container clusters list | grep -q RUNNING; do
  echo "Cluster not ready yet, waiting..."
  sleep 10
done

# Get cluster credentials
echo "Getting cluster credentials..."
gcloud container clusters get-credentials day2-ops --region europe-west1

# Verify nodes
echo "Verifying GKE nodes are ready..."
kubectl get nodes

# Clone demo repo
echo "Cloning microservices demo repository..."
git clone https://github.com/GoogleCloudPlatform/microservices-demo.git
cd microservices-demo

# Deploy application
echo "Deploying Online Boutique application..."
kubectl apply -f release/kubernetes-manifests.yaml

# Wait for pods to be ready
echo "Waiting for all pods to be running..."
while [[ $(kubectl get pods | grep -v "Running\|Completed" | wc -l) -gt 1 ]]; do
  echo "Not all pods are ready yet, waiting..."
  sleep 10
  kubectl get pods
done

# Get external IP
echo "Getting application external IP..."
until kubectl get service frontend-external -o jsonpath="{.status.loadBalancer.ingress[0].ip}" &> /dev/null; do
  echo "External IP not assigned yet, waiting..."
  sleep 10
done

export EXTERNAL_IP=$(kubectl get service frontend-external -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
echo "Application is accessible at: http://${EXTERNAL_IP}"

# Test application
echo "Testing application accessibility..."
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}\n" http://${EXTERNAL_IP})
if [ "$HTTP_STATUS" == "200" ]; then
  echo "✅ Application is up and running!"
else
  echo "⚠️ Application returned HTTP status: $HTTP_STATUS"
fi

echo ""
echo "==== Setup Complete ===="
echo "Next steps:"
echo "1. Set up Log Analytics in the Google Cloud Console"
echo "2. Create log buckets and sinks as described in the README"
echo "3. Start analyzing your application logs"
echo ""
