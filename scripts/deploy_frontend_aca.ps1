# Azure Container Apps deployment script for Flutter web frontend

# Stop on first error
$ErrorActionPreference = "Stop"

# Enable debug output
$DebugPreference = "Continue"
Write-Debug "Starting deployment script..."

# Login to Azure
Write-Host "Logging into Azure..."
az login
az account show

# Configuration
$RESOURCE_GROUP = "rg-mdelehaye-cv"
$LOCATION = "eastus"
$REGISTRY = "crmdelehayecv"  # Match backend registry name
$FRONTEND_APP = "frontend-mdelehaye-cv"
$FRONTEND_IMAGE = "$REGISTRY.azurecr.io/cv-flutter-web:latest"
$ENVIRONMENT = "calorie-tracker-env"  # Use existing environment
$ENVIRONMENT_RG = "calorie-tracker-rg"  # Resource group of the existing environment

Write-Debug "Configuration loaded"
Write-Debug "Resource Group: $RESOURCE_GROUP"
Write-Debug "Registry: $REGISTRY"
Write-Debug "Frontend App: $FRONTEND_APP"
Write-Debug "Environment: $ENVIRONMENT"

# Get environment ID
Write-Host "Getting environment ID..."
$ENVIRONMENT_ID = az containerapp env show --name $ENVIRONMENT --resource-group $ENVIRONMENT_RG --query id -o tsv
Write-Debug "Environment ID: $ENVIRONMENT_ID"

# Get project root directory
$projectRoot = Split-Path -Parent $PSScriptRoot
Write-Debug "Project root: $projectRoot"

# Create or get ACR
Write-Host "Checking ACR..."
try {
    $acrExists = $null -ne (az acr show --name $REGISTRY --resource-group $RESOURCE_GROUP 2>$null)
    Write-Debug "ACR exists: $acrExists"
} catch {
    Write-Error "Error checking ACR: $_"
    # exit 1
}

if (!$acrExists) {
    Write-Host "Creating Azure Container Registry..."
    try {
        az acr create --resource-group $RESOURCE_GROUP --name $REGISTRY --sku Basic --admin-enabled true
    } catch {
        Write-Error "Error creating ACR: $_"
        # exit 1
    }
}

# Get ACR credentials
Write-Host "Getting ACR credentials..."
try {
    $ACR_USERNAME = az acr credential show --name $REGISTRY --query "username" -o tsv
    $ACR_PASSWORD = az acr credential show --name $REGISTRY --query "passwords[0].value" -o tsv
    Write-Debug "ACR username obtained: $($ACR_USERNAME -ne $null)"
} catch {
    Write-Error "Error getting ACR credentials: $_"
    # exit 1
}

# Login to ACR
Write-Host "Logging into Azure Container Registry..."
$loginCmd = "echo '$ACR_PASSWORD' | docker login '$REGISTRY.azurecr.io' --username $ACR_USERNAME --password-stdin"
Write-Debug "Login command: $loginCmd"
Invoke-Expression $loginCmd

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to login to ACR"
    exit 1
}

# Create secrets for ACR credentials
Write-Host "Creating secrets for ACR credentials..."
$createSecretsCmd = "az containerapp secret set " + `
    "--name $FRONTEND_APP " + `
    "--resource-group $RESOURCE_GROUP " + `
    "--secrets " + `
    "backend-url='$BACKEND_URL'"

Write-Debug "Creating secrets command: $createSecretsCmd"
Invoke-Expression $createSecretsCmd

# Check if frontend app exists
Write-Host "Checking if frontend app exists..."
try {
    $checkApp = az containerapp show --name $FRONTEND_APP --resource-group $RESOURCE_GROUP 2>&1
    $frontendExists = $LASTEXITCODE -eq 0
    Write-Debug "Frontend app exists: $frontendExists"
    Write-Debug "Check app output: $checkApp"
} catch {
    Write-Warning "Error checking frontend app (this is expected if it doesn't exist): $_"
    $frontendExists = $false
}

# Build Flutter web app
Write-Host "Building Flutter web app..."
$flutterAppPath = Join-Path -Path $projectRoot -ChildPath "cv_flutter_app"
Write-Debug "Flutter app path: $flutterAppPath"

if (!(Test-Path $flutterAppPath)) {
    Write-Error "Flutter app directory not found at: $flutterAppPath"
    # exit 1
}

# Build and push Docker image
Write-Host "Building and pushing Docker image..."
Set-Location -Path $flutterAppPath
docker build -t $FRONTEND_IMAGE . `
    --build-arg BACKEND_URL=$BACKEND_URL
az acr login --name $REGISTRY
docker push $FRONTEND_IMAGE

if ($frontendExists) {
    Write-Host "Updating existing frontend app..."
    
    # First update the secrets
    Write-Host "Updating secrets..."
    $secretsCmd = "az containerapp secret set " + `
        "--name $FRONTEND_APP " + `
        "--resource-group $RESOURCE_GROUP " + `
        "--secrets " + `
        "backend-url='$BACKEND_URL'"
    
    Write-Debug "Secrets command: $secretsCmd"
    Invoke-Expression $secretsCmd

    # Update the container app
    $updateCmd = "az containerapp update " + `
        "--name $FRONTEND_APP " + `
        "--resource-group $RESOURCE_GROUP " + `
        "--image $FRONTEND_IMAGE " + `
        "--registry-server '$REGISTRY.azurecr.io' " + `
        "--registry-username $ACR_USERNAME " + `
        "--registry-password $ACR_PASSWORD " + `
        "--secrets " + `
        "backend-url='$BACKEND_URL' " + `
        "--set-env-vars " + `
        "BACKEND_URL=secretref:backend-url " + `
        "--query properties.configuration.ingress.fqdn"

    Write-Debug "Update command: $updateCmd"
    $FRONTEND_URL = Invoke-Expression "$updateCmd -o tsv"
} else {
    Write-Host "Creating new frontend app..."
    
    # Create the container app with initial secrets
    $createCmd = "az containerapp create " + `
        "--name $FRONTEND_APP " + `
        "--resource-group $RESOURCE_GROUP " + `
        "--environment '$ENVIRONMENT_ID' " + `
        "--image $FRONTEND_IMAGE " + `
        "--target-port 80 " + `
        "--ingress 'external' " + `
        "--registry-server '$REGISTRY.azurecr.io' " + `
        "--registry-username $ACR_USERNAME " + `
        "--registry-password $ACR_PASSWORD " + `
        "--secrets " + `
        "backend-url='$BACKEND_URL' " + `
        "--env-vars " + `
        "ENVIRONMENT=production " + `
        "BACKEND_URL=secretref:backend-url " + `
        "--query properties.configuration.ingress.fqdn"

    Write-Debug "Create command: $createCmd"
    $FRONTEND_URL = Invoke-Expression "$createCmd -o tsv"
}

# Return to original directory
Set-Location -Path $PSScriptRoot

Write-Host "Frontend deployed successfully!"
Write-Host "Frontend URL: https://$FRONTEND_URL" 