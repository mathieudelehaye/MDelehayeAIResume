# Azure deployment configuration
$RESOURCE_GROUP = "rg-mdelehaye-cv"
$LOCATION = "eastus"  # Changed to eastus to match existing environment
$ENVIRONMENT = "calorie-tracker-env"  # Use existing environment
$ENVIRONMENT_RG = "calorie-tracker-rg"  # Resource group of the existing environment
$BACKEND_APP = "backend-mdelehaye-cv"
$REGISTRY = "crmdelehayecv"
$BACKEND_IMAGE = "$REGISTRY.azurecr.io/backend:latest"

# Get the current directory where the script is being run from
$currentDir = Get-Location

# Try to find the .env file in various locations
$possibleEnvPaths = @(
    (Join-Path $currentDir "chatbot_backend/.env"),
    (Join-Path $currentDir "../chatbot_backend/.env"),
    (Join-Path $currentDir "../../chatbot_backend/.env")
)

$envPath = $null
foreach ($path in $possibleEnvPaths) {
    Write-Host "Checking for .env file at: $path"
    if (Test-Path $path) {
        $envPath = $path
        Write-Host "Found .env file at: $path"
        break
    }
}

if (-not $envPath) {
    Write-Error "Could not find .env file in any of the expected locations."
    Write-Host "Please create a .env file in the chatbot_backend directory with your Neon database settings:"
    Write-Host "POSTGRES_HOST=your-db.neon.tech"
    Write-Host "POSTGRES_PORT=5432"
    Write-Host "POSTGRES_DB=your-db-name"
    Write-Host "POSTGRES_USER=your-username"
    Write-Host "POSTGRES_PASSWORD=your-password"
    # exit 1
}

# Read and parse the .env file
Write-Host "`nReading .env file content:"
$envContent = Get-Content $envPath
Write-Host "Found $(($envContent | Measure-Object).Count) lines in .env file"

$envVars = @{}
foreach ($line in $envContent) {
    Write-Host "Processing line: $line"
    if ($line -match '^\s*([^#][^=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        Write-Host "Found variable: $key = $value"
        $envVars[$key] = $value
    } elseif ($line.Trim() -ne "") {
        Write-Host "Warning: Skipping line that doesn't match expected format: $line"
    }
}

Write-Host "`nParsed environment variables:"
$envVars.Keys | ForEach-Object {
    $value = if ($_ -like '*PASSWORD*') { '********' } else { $envVars[$_] }
    Write-Host "$_ = $value"
}

# Validate required environment variables
$requiredVars = @(
    "POSTGRES_HOST",
    "POSTGRES_PORT",
    "POSTGRES_DB",
    "POSTGRES_USER",
    "POSTGRES_PASSWORD",
    "OPENAI_API_KEY",  # Added OpenAI API key requirement
    "DATABASE_URL"  # Added DATABASE_URL requirement
)

$missingVars = @()
foreach ($var in $requiredVars) {
    if (-not $envVars.ContainsKey($var)) {
        $missingVars += $var
        Write-Error "Missing required environment variable: $var"
    }
}

if ($missingVars.Count -gt 0) {
    Write-Host "`nMissing required variables: $($missingVars -join ', ')"
    Write-Host "Please update your .env file with the missing variables"
    # exit 1
}

Write-Host "`nSuccessfully loaded database configuration from .env file"
Write-Host "Database Host: $($envVars['POSTGRES_HOST'])"
Write-Host "Database Name: $($envVars['POSTGRES_DB'])"
Write-Host "Database User: $($envVars['POSTGRES_USER'])"

# Check if Docker is installed
if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
    Write-Error "Docker is not installed. Please install Docker Desktop first."
    # exit 1
}

# Check if Azure CLI is installed
if (-not (Get-Command "az" -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI is not installed. Please install it first."
    # exit 1
}

# Login to Azure
Write-Host "`nLogging in to Azure..."
az login

Write-Host "`nUsing existing Container Apps environment: $ENVIRONMENT from resource group $ENVIRONMENT_RG"

# Create ACR if it doesn't exist
Write-Host "`nChecking if Azure Container Registry exists..."
$acrExists = az acr list --resource-group $RESOURCE_GROUP --query "[?name=='$REGISTRY'].name" -o tsv

if ($acrExists) {
    Write-Host "Azure Container Registry $REGISTRY already exists"
} else {
    Write-Host "Creating Azure Container Registry..."
    az acr create `
        --resource-group $RESOURCE_GROUP `
        --name $REGISTRY `
        --sku Basic `
        --admin-enabled true
}

# Get ACR credentials
Write-Host "`nGetting ACR credentials..."
$ACR_USERNAME = az acr credential show --name $REGISTRY --query "username" -o tsv
$ACR_PASSWORD = az acr credential show --name $REGISTRY --query "passwords[0].value" -o tsv

# Login to ACR
Write-Host "`nLogging in to ACR..."
echo $ACR_PASSWORD | docker login "$REGISTRY.azurecr.io" -u $ACR_USERNAME --password-stdin

# Build and push the Docker image
Write-Host "`nBuilding and pushing Docker image..."
Write-Host "Building image: $BACKEND_IMAGE"
docker build -t $BACKEND_IMAGE ./chatbot_backend
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker build failed"
    # exit 1
}

Write-Host "Pushing image to ACR..."
docker push $BACKEND_IMAGE
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker push failed"
    # exit 1
}

# Get the full resource ID of the Container Apps environment
Write-Host "`nGetting Container Apps environment resource ID..."
$ENVIRONMENT_ID = az containerapp env show --name $ENVIRONMENT --resource-group $ENVIRONMENT_RG --query id -o tsv

if (-not $ENVIRONMENT_ID) {
    Write-Error "Could not find Container Apps environment $ENVIRONMENT in resource group $ENVIRONMENT_RG"
    # exit 1
}

Write-Host "Using environment: $ENVIRONMENT_ID"

# Check if backend app already exists
Write-Host "`nChecking if backend app already exists..."
$backendExists = az containerapp list --resource-group $RESOURCE_GROUP --query "[?name=='$BACKEND_APP'].name" -o tsv

if ($backendExists) {
    Write-Host "Updating existing backend app..."
    
    # First update the secrets
    Write-Host "Updating secrets..."
    $secretsCmd = "az containerapp secret set " + `
        "--name $BACKEND_APP " + `
        "--resource-group $RESOURCE_GROUP " + `
        "--secrets " + `
        "openai-api-key='$($envVars['OPENAI_API_KEY'])' " + `
        "database-url='$($envVars['DATABASE_URL'])'"
    
    Invoke-Expression $secretsCmd

    # Then update the container app
    Write-Host "Updating container app configuration..."
    $updateCmd = "az containerapp update " + `
        "--name $BACKEND_APP " + `
        "--resource-group $RESOURCE_GROUP " + `
        "--image $BACKEND_IMAGE " + `
        "--set-env-vars " + `
        "ENVIRONMENT=production " + `
        "OPENAI_API_KEY=secretref:openai-api-key " + `
        "DATABASE_URL=secretref:database-url " + `
        "ALLOWED_ORIGINS=https://frontend-mdelehaye-cv.wittyflower-c2822a5a.eastus.azurecontainerapps.io/"

    # Update registry credentials separately if needed
    Write-Host "Updating registry credentials..."
    $registryCmd = "az containerapp registry set " + `
        "--name $BACKEND_APP " + `
        "--resource-group $RESOURCE_GROUP " + `
        "--server '$REGISTRY.azurecr.io' " + `
        "--username $ACR_USERNAME " + `
        "--password '$ACR_PASSWORD'"

    Invoke-Expression $registryCmd
    $BACKEND_URL = Invoke-Expression "$updateCmd --query 'properties.configuration.ingress.fqdn' -o tsv"
} else {
    Write-Host "Creating new backend app..."
    
    $createCmd = "az containerapp create " + `
        "--name $BACKEND_APP " + `
        "--resource-group $RESOURCE_GROUP " + `
        "--environment '$ENVIRONMENT_ID' " + `
        "--image $BACKEND_IMAGE " + `
        "--target-port 8000 " + `
        "--ingress external " + `
        "--registry-server '$REGISTRY.azurecr.io' " + `
        "--registry-username $ACR_USERNAME " + `
        "--registry-password '$ACR_PASSWORD' " + `
        "--secrets " + `
        "openai-api-key='$($envVars['OPENAI_API_KEY'])' " + `
        "database-url='$($envVars['DATABASE_URL'])' " + `
        "--env-vars " + `
        "ENVIRONMENT=production " + `
        "OPENAI_API_KEY=secretref:openai-api-key " + `
        "DATABASE_URL=secretref:database-url " + `
        "ALLOWED_ORIGINS=https://frontend-mdelehaye-cv.wittyflower-c2822a5a.eastus.azurecontainerapps.io/"

    $BACKEND_URL = Invoke-Expression "$createCmd --query 'properties.configuration.ingress.fqdn' -o tsv"
}

Write-Host "`nBackend deployed successfully!"
Write-Host "Backend URL: https://$BACKEND_URL"

# Function to check container logs
function Show-ContainerLogs {
    param (
        [string]$containerAppName,
        [string]$resourceGroup,
        [int]$tail = 50
    )
    
    Write-Host "`nFetching logs for $containerAppName..."
    az containerapp logs show `
        --name $containerAppName `
        --resource-group $resourceGroup `
        --tail $tail
}

# Show logs after deployment
Write-Host "`nChecking container logs..."
Show-ContainerLogs -containerAppName $BACKEND_APP -resourceGroup $RESOURCE_GROUP

Write-Host "`nTo check logs again, run:"
Write-Host "az containerapp logs show --name $BACKEND_APP --resource-group $RESOURCE_GROUP --tail 50" 