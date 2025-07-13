# ===========================================
# Graziele - ERPNext + ChatGPT PowerShell Setup
# ===========================================

$PROJECT_NAME = "erpnext-one"
$SITE_NAME = "erp-next"
$DB_NAME = "brand_new_db"
$DB_ROOT_PASSWORD = "admin"
$ADMIN_PASSWORD = "admin"
$OPENAI_APP_REPO = "https://github.com/williamluke4/erpnext_chatgpt.git"
$ERPNEXT_VERSION = "v15.29.0"
$FRAPPE_VERSION = "v15.32.0"
$SITE = "localhost"
$ERP_DOCKER_IMAGE_NAME = "frappe/erpnext:latest"

Write-Host "🚀 Starting ERPNext + OpenAI setup..." -ForegroundColor Green

# 1. Check if Docker is installed
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Docker is not installed. Please install Docker Desktop." -ForegroundColor Red
    exit 1
}

# 2. Choose an available port
$PORT = 8080
while ((Get-NetTCPConnection -LocalPort $PORT -ErrorAction SilentlyContinue)) {
    $PORT++
}
Write-Host "✅ Using port $PORT" -ForegroundColor Green

# 3. Clean up previous setup
if (Test-Path "frappe_docker") {
    Remove-Item -Recurse -Force "frappe_docker"
}

# 4. Clone Frappe Docker repository
git clone https://github.com/frappe/frappe_docker.git
Set-Location frappe_docker

# 5. Create the .env file
$envContent = @"
DB_PASSWORD=$DB_ROOT_PASSWORD
DB_HOST=mariadb-database
DB_PORT=3306
SITES=$SITE_NAME
ROUTER=$PROJECT_NAME
BENCH_NETWORK=$PROJECT_NAME

# 👇 These 3 lines were REMOVED:
# CUSTOM_IMAGE=frappe_custom
# CUSTOM_TAG=latest
# PULL_POLICY=never

OPENAI_API_KEY=
"@
$envContent | Out-File -FilePath ".env" -Encoding UTF8

# 6. Verify ERPNext Docker image version (optional)
docker run --rm frappe/erpnext:$ERPNEXT_VERSION version

# Copy the erpnext_chatgpt app into the container's apps directory
Copy-Item ..\erpnext_chatgpt -Destination apps -Recurse -Force

# 7. Launch containers
docker compose down --remove-orphans -v
docker pull $ERP_DOCKER_IMAGE_NAME
docker compose up -d

# 8. Wait for database and Redis to initialize
Start-Sleep -Seconds 30

# 9. Create the site if it doesn't exist
$siteExists = docker compose exec backend ls /home/frappe/frappe-bench/sites/$SITE_NAME 2>$null
if ($LASTEXITCODE -ne 0) {
    docker compose exec backend bench new-site $SITE_NAME `
        --db-name $DB_NAME `
        --mariadb-root-username root `
        --mariadb-root-password $DB_ROOT_PASSWORD `
        --admin-password $ADMIN_PASSWORD `
        --install-app erpnext `
        --force
}

# 10. Install the erpnext_chatgpt app
docker compose exec backend bench get-app erpnext_chatgpt $OPENAI_APP_REPO
docker compose exec backend bench --site $SITE_NAME install-app erpnext_chatgpt

# 11. 🔧 Compile assets (ESSENTIAL for the button to show!)
docker compose exec backend bench build
docker compose exec backend bench clear-cache
docker compose exec backend bench restart

# 12. Completion
Write-Host ""
Write-Host "✅ ERPNext with ChatGPT is ready!" -ForegroundColor Green
Write-Host "Access it at: http://$SITE`:$PORT" -ForegroundColor Cyan
Write-Host "Login: Administrator | Password: $ADMIN_PASSWORD" -ForegroundColor White
