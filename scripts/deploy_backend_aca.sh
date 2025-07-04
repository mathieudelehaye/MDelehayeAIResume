#!/usr/bin/env bash
# Deploy FastAPI backend to Azure Container Apps
# Usage: ./scripts/deploy_backend_aca.sh <RESOURCE_GROUP> <LOCATION> <ACR_NAME> <IMAGE_TAG>

set -euo pipefail

RESOURCE_GROUP=${1:-rg-cvresume}
LOCATION=${2:-westeurope}
ACR_NAME=${3:-cvresumeacr}
IMAGE_TAG=${4:-v1}

ACA_ENV="cvresume-env"
API_APP="cv-resume-api"

# Login to Azure (expects az cli already logged in)

echo "Creating resource group: $RESOURCE_GROUP ($LOCATION)"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

echo "Creating Azure Container Registry: $ACR_NAME"
az acr create \
  --name "$ACR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Basic \
  --admin-enabled true

# Build & push Docker image using ACR build (no local docker needed)
echo "Building image using ACR build ..."
cd chatbot_backend && \
az acr build \
  --registry "$ACR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --image "$API_APP:$IMAGE_TAG" \
  --file Dockerfile .

# Enable containerapp extension if missing
az extension add --name containerapp --upgrade --yes

# Create Container Apps environment (if not exists)
echo "Creating Container Apps environment: $ACA_ENV"
az containerapp env create \
  --name "$ACA_ENV" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION"

# Collect secrets
echo "Setting up application secrets..."
read -sp "Enter your OpenAI API key: " OPENAI_KEY
echo
read -sp "Enter your Database URL: " DATABASE_URL
echo

# Store secrets in Azure Container Apps
echo "Storing secrets in Azure Container Apps..."
az containerapp secret set \
  --name "$API_APP" \
  --resource-group "$RESOURCE_GROUP" \
  --secrets \
    openai-key="$OPENAI_KEY" \
    database-url="$DATABASE_URL"

echo "Deploying container app: $API_APP"
az containerapp create \
  --name "$API_APP" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$ACA_ENV" \
  --image "$ACR_NAME.azurecr.io/$API_APP:$IMAGE_TAG" \
  --registry-server "$ACR_NAME.azurecr.io" \
  --target-port 8000 \
  --ingress external \
  --cpu 0.5 --memory 1Gi \
  --min-replicas 1 --max-replicas 3 \
  --secrets \
    openai-key="$OPENAI_KEY" \
    database-url="$DATABASE_URL" \
  --env-vars \
    OPENAI_API_KEY=secretref:openai-key \
    DATABASE_URL=secretref:database-url \
    ENVIRONMENT=production

echo "Fetching application URL ..."
APP_URL=$(az containerapp show --name "$API_APP" --resource-group "$RESOURCE_GROUP" --query properties.configuration.ingress.fqdn -o tsv)
echo "Backend deployed at: https://$APP_URL" 