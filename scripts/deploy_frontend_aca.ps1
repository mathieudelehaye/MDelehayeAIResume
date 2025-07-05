# Azure Container Apps deployment script for Flutter web frontend

# Stop on first error
$ErrorActionPreference = "Stop"

# Enable debug output
$DebugPreference = "Continue"
Write-Debug "Starting deployment script..."

# Configuration
$RESOURCE_GROUP = "rg-mdelehaye-cv"
$LOCATION = "eastus"
$REGISTRY = "crmdelehayecv"  # Match backend registry name
$FRONTEND_APP = "frontend-mdelehaye-cv"
$FRONTEND_IMAGE = "$REGISTRY.azurecr.io/cv-flutter-web:latest"
$ENVIRONMENT = "calorie-tracker-env"  # Use existing environment
$ENVIRONMENT_RG = "calorie-tracker-rg"  # Resource group of the existing environment

# Backend URL - UPDATE THIS to match your deployed backend
$BACKEND_URL = "https://backend-mdelehaye-cv.wittyflower-c2822a5a.eastus.azurecontainerapps.io"

Write-Debug "Configuration loaded"
Write-Debug "Resource Group: $RESOURCE_GROUP"
Write-Debug "Registry: $REGISTRY"
Write-Debug "Frontend App: $FRONTEND_APP"
Write-Debug "Environment: $ENVIRONMENT"
Write-Debug "Backend URL: $BACKEND_URL"

# Login to Azure
Write-Host "Logging into Azure..."
az login
az account show

# Get environment ID
Write-Host "Getting environment ID..."
$ENVIRONMENT_ID = az containerapp env show --name $ENVIRONMENT --resource-group $ENVIRONMENT_RG --query id -o tsv
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get environment ID"
    # exit 1
}
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
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create ACR"
            # exit 1
        }
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
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to get ACR credentials"
        # exit 1
    }
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
    # exit 1
}

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

# Build and push Docker image
Write-Host "Building and pushing Docker image..."
Write-Host "Building from cv_flutter_app directory"
Write-Host "Using backend URL: $BACKEND_URL"

# Set location to cv_flutter_app directory since Dockerfile expects build context to be there
$flutterAppPath = Join-Path -Path $projectRoot -ChildPath "cv_flutter_app"
Set-Location -Path $flutterAppPath

# Build Docker image with build context from cv_flutter_app directory
$buildCmd = "docker build -t $FRONTEND_IMAGE --build-arg BACKEND_URL='$BACKEND_URL' ."
Write-Debug "Build command: $buildCmd"
Invoke-Expression $buildCmd

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build Docker image"
    # exit 1
}

# Login to ACR and push
Write-Host "Logging into ACR and pushing image..."
az acr login --name $REGISTRY
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to login to ACR"
    # exit 1
}

docker push $FRONTEND_IMAGE
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to push Docker image"
    # exit 1
}

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
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to update secrets"
        # exit 1
    }

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
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to update container app"
        # exit 1
    }
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
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create container app"
        # exit 1
    }
}

# Return to original directory
Set-Location -Path $PSScriptRoot

Write-Host "Frontend deployed successfully!"
Write-Host "Frontend URL: https://$FRONTEND_URL"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Test the frontend at: https://$FRONTEND_URL"
Write-Host "2. Verify the AI chat functionality works"
Write-Host "3. Check browser console for any errors" 