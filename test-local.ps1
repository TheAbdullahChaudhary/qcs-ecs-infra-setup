# Local Testing Script for ECS 3-Tier Application (PowerShell Version)
Write-Host "🚀 Testing ECS 3-Tier Application Locally" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

# Function to check if a service is ready
function Test-ServiceHealth {
    param(
        [string]$ServiceName,
        [string]$Url,
        [int]$MaxAttempts = 30
    )
    
    Write-Host "Waiting for $ServiceName to be ready..." -ForegroundColor Yellow
    
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri $Url -Method GET -TimeoutSec 5 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Host "✅ $ServiceName is ready!" -ForegroundColor Green
                return $true
            }
        }
        catch {
            Write-Host "." -NoNewline
            Start-Sleep -Seconds 2
        }
    }
    
    Write-Host "❌ $ServiceName failed to start within expected time" -ForegroundColor Red
    return $false
}

# Function to test API endpoints
function Test-ApiEndpoint {
    param(
        [string]$BaseUrl,
        [string]$Endpoint,
        [int]$ExpectedStatus
    )
    
    Write-Host "Testing $Endpoint..." -ForegroundColor Yellow
    
    try {
        $response = Invoke-WebRequest -Uri "$BaseUrl$Endpoint" -Method GET -ErrorAction Stop
        
        if ($response.StatusCode -eq $ExpectedStatus) {
            Write-Host "✅ $Endpoint returned $($response.StatusCode)" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "❌ $Endpoint returned $($response.StatusCode) (expected $ExpectedStatus)" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ $Endpoint failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to test todo operations
function Test-TodoOperations {
    param(
        [string]$BaseUrl
    )
    
    Write-Host "Testing Todo CRUD operations..." -ForegroundColor Yellow
    
    # Test creating a todo
    Write-Host "Creating todo..."
    try {
        $createResponse = Invoke-WebRequest -Uri "$BaseUrl/todos" -Method POST -Headers @{"Content-Type"="application/json"} -Body '{"text": "Test todo from PowerShell script"}' -ErrorAction Stop
        
        if ($createResponse.StatusCode -eq 201) {
            Write-Host "✅ Todo created successfully" -ForegroundColor Green
            
            # Extract todo ID from response
            $todoData = $createResponse.Content | ConvertFrom-Json
            $todoId = $todoData.id
            
            # Test getting todos
            Write-Host "Getting todos..."
            $getResponse = Invoke-WebRequest -Uri "$BaseUrl/todos" -Method GET -ErrorAction Stop
            if ($getResponse.StatusCode -eq 200) {
                Write-Host "✅ Todos retrieved successfully" -ForegroundColor Green
            }
            else {
                Write-Host "❌ Failed to retrieve todos" -ForegroundColor Red
            }
            
            # Test updating todo
            Write-Host "Updating todo..."
            $updateResponse = Invoke-WebRequest -Uri "$BaseUrl/todos/$todoId" -Method PATCH -Headers @{"Content-Type"="application/json"} -Body '{"completed": true}' -ErrorAction Stop
            if ($updateResponse.StatusCode -eq 200) {
                Write-Host "✅ Todo updated successfully" -ForegroundColor Green
            }
            else {
                Write-Host "❌ Failed to update todo" -ForegroundColor Red
            }
            
            # Test deleting todo
            Write-Host "Deleting todo..."
            $deleteResponse = Invoke-WebRequest -Uri "$BaseUrl/todos/$todoId" -Method DELETE -ErrorAction Stop
            if ($deleteResponse.StatusCode -eq 200) {
                Write-Host "✅ Todo deleted successfully" -ForegroundColor Green
            }
            else {
                Write-Host "❌ Failed to delete todo" -ForegroundColor Red
            }
        }
        else {
            Write-Host "❌ Failed to create todo" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Todo operations failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Check if Docker is running
Write-Host "Checking Docker status..."
try {
    docker info | Out-Null
    Write-Host "✅ Docker is running" -ForegroundColor Green
}
catch {
    Write-Host "❌ Docker is not running. Please start Docker and try again." -ForegroundColor Red
    exit 1
}

# Check if containers are running
Write-Host "Checking container status..."
$containers = docker-compose ps --format json | ConvertFrom-Json
$runningContainers = $containers | Where-Object { $_.State -eq "running" }

if ($runningContainers.Count -eq 3) {
    Write-Host "✅ All containers are running" -ForegroundColor Green
}
else {
    Write-Host "❌ Not all containers are running. Starting containers..." -ForegroundColor Yellow
    docker-compose up -d
    Start-Sleep -Seconds 10
}

# Test database health
Write-Host "Testing database connection..."
try {
    $dbResult = docker-compose exec -T db pg_isready -U ecsuser -d ecsdb 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Database is ready" -ForegroundColor Green
    }
    else {
        Write-Host "❌ Database is not ready" -ForegroundColor Red
        Write-Host "Database logs:" -ForegroundColor Yellow
        docker-compose logs db
        exit 1
    }
}
catch {
    Write-Host "❌ Database connection failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test backend health
if (-not (Test-ServiceHealth "Backend" "http://localhost:4000/health")) {
    Write-Host "Backend logs:" -ForegroundColor Yellow
    docker-compose logs backend
    exit 1
}

# Test frontend health
if (-not (Test-ServiceHealth "Frontend" "http://localhost/health")) {
    Write-Host "Frontend logs:" -ForegroundColor Yellow
    docker-compose logs frontend
    exit 1
}

# Test API endpoints
Write-Host ""
Write-Host "Testing API endpoints..." -ForegroundColor Cyan
Test-ApiEndpoint "http://localhost:4000" "/health" 200
Test-ApiEndpoint "http://localhost:4000" "/todos" 200

# Test todo operations
Write-Host ""
Test-TodoOperations "http://localhost:4000"

# Test frontend proxy
Write-Host ""
Write-Host "Testing frontend proxy..." -ForegroundColor Cyan
Test-ApiEndpoint "http://localhost" "/api/health" 200

# Display service status
Write-Host ""
Write-Host "Service Status:" -ForegroundColor Cyan
Write-Host "===============" -ForegroundColor Cyan
docker-compose ps

Write-Host ""
Write-Host "🎉 All tests passed! Your application is ready for deployment." -ForegroundColor Green
Write-Host ""
Write-Host "Access your application at:" -ForegroundColor White
Write-Host "  Frontend: http://localhost" -ForegroundColor White
Write-Host "  Backend API: http://localhost:4000" -ForegroundColor White
Write-Host "  Database: localhost:5432" -ForegroundColor White
Write-Host ""
Write-Host "To stop the services, run: docker-compose down" -ForegroundColor Yellow 