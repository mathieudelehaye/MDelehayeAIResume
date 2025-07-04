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


# Always (re)generate nginx configuration template
$nginxConfigPath = Join-Path -Path $flutterAppPath -ChildPath "default.conf.template"
Write-Host "Writing nginx configuration template..."
$nginxConfig = @"
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://`${BACKEND_URL};";

    # Gzip Settings
    gzip on;
    gzip_vary on;
    gzip_min_length 10240;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml application/javascript;
    gzip_disable "MSIE [1-6]\.";

    location / {
        try_files `$uri `$uri/ /index.html;
        expires 1h;
        add_header Cache-Control "public, no-transform";
    }

    location /api/ {
        rewrite ^/api/(.*) /`$1 break;
        proxy_pass https://`${BACKEND_URL};
        proxy_http_version 1.1;
        proxy_set_header Upgrade `$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host `$host;
        proxy_cache_bypass `$http_upgrade;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
    }

    # Handle Flutter routing - match all locations except /api/
    location ~ ^(?!/api/).* {
        try_files `$uri `$uri/ /index.html;
    }
}
"@

$nginxConfig | Set-Content $nginxConfigPath

# Create Dockerfile for Flutter web if it doesn't exist
$dockerfilePath = Join-Path -Path $flutterAppPath -ChildPath "Dockerfile"
if (!(Test-Path $dockerfilePath)) {
    Write-Host "Creating Dockerfile..."
    @"
FROM nginx:alpine

# Copy the built Flutter web app
COPY build/web /usr/share/nginx/html

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Create directory for runtime environment config
RUN mkdir -p /usr/share/nginx/html/assets/config

# Copy environment script
COPY env.sh /docker-entrypoint.d/40-env.sh
RUN chmod +x /docker-entrypoint.d/40-env.sh

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
"@ | Set-Content $dockerfilePath
}

# Create environment script for runtime configuration
$envScriptPath = Join-Path -Path $flutterAppPath -ChildPath "env.sh"
Write-Host "Creating environment script..."
@"
#!/bin/sh

# Create runtime environment configuration
cat > /usr/share/nginx/html/assets/config/env.js <<EOF
window.env = {
  'BACKEND_URL': '${"$BACKEND_URL"}'
};
EOF
"@ | Set-Content $envScriptPath -NoNewline

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