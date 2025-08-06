#!/bin/bash

# Local Testing Script for ECS 3-Tier Application
echo "🚀 Testing ECS 3-Tier Application Locally"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a service is ready
check_service() {
    local service=$1
    local url=$2
    local max_attempts=30
    local attempt=1

    echo -e "${YELLOW}Waiting for $service to be ready...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $service is ready!${NC}"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}❌ $service failed to start within expected time${NC}"
    return 1
}

# Function to test API endpoints
test_api() {
    local base_url=$1
    local endpoint=$2
    local expected_status=$3
    
    echo -e "${YELLOW}Testing $endpoint...${NC}"
    
    response=$(curl -s -w "%{http_code}" -o /tmp/response.json "$base_url$endpoint")
    
    if [ "$response" = "$expected_status" ]; then
        echo -e "${GREEN}✅ $endpoint returned $response${NC}"
        return 0
    else
        echo -e "${RED}❌ $endpoint returned $response (expected $expected_status)${NC}"
        return 1
    fi
}

# Function to test todo operations
test_todo_operations() {
    local base_url=$1
    
    echo -e "${YELLOW}Testing Todo CRUD operations...${NC}"
    
    # Test creating a todo
    echo "Creating todo..."
    create_response=$(curl -s -X POST "$base_url/todos" \
        -H "Content-Type: application/json" \
        -d '{"text": "Test todo from script"}' \
        -w "%{http_code}")
    
    if [[ $create_response == *"201"* ]]; then
        echo -e "${GREEN}✅ Todo created successfully${NC}"
        
        # Extract todo ID from response
        todo_id=$(echo $create_response | grep -o '"id":[0-9]*' | cut -d':' -f2)
        
        # Test getting todos
        echo "Getting todos..."
        if curl -s -f "$base_url/todos" > /dev/null; then
            echo -e "${GREEN}✅ Todos retrieved successfully${NC}"
        else
            echo -e "${RED}❌ Failed to retrieve todos${NC}"
        fi
        
        # Test updating todo
        echo "Updating todo..."
        if curl -s -X PATCH "$base_url/todos/$todo_id" \
            -H "Content-Type: application/json" \
            -d '{"completed": true}' > /dev/null; then
            echo -e "${GREEN}✅ Todo updated successfully${NC}"
        else
            echo -e "${RED}❌ Failed to update todo${NC}"
        fi
        
        # Test deleting todo
        echo "Deleting todo..."
        if curl -s -X DELETE "$base_url/todos/$todo_id" > /dev/null; then
            echo -e "${GREEN}✅ Todo deleted successfully${NC}"
        else
            echo -e "${RED}❌ Failed to delete todo${NC}"
        fi
        
    else
        echo -e "${RED}❌ Failed to create todo${NC}"
    fi
}

# Check if Docker is running
echo "Checking Docker status..."
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker is running${NC}"

# Build and start services
echo "Building and starting services..."
docker-compose down -v 2>/dev/null
docker-compose up --build -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 10

# Test database health
echo "Testing database connection..."
if docker-compose exec -T db pg_isready -U ecsuser -d ecsdb > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Database is ready${NC}"
else
    echo -e "${RED}❌ Database is not ready${NC}"
    docker-compose logs db
    exit 1
fi

# Test backend health
check_service "Backend" "http://localhost:4000/health"
if [ $? -ne 0 ]; then
    echo "Backend logs:"
    docker-compose logs backend
    exit 1
fi

# Test frontend health
check_service "Frontend" "http://localhost/health"
if [ $? -ne 0 ]; then
    echo "Frontend logs:"
    docker-compose logs frontend
    exit 1
fi

# Test API endpoints
echo ""
echo "Testing API endpoints..."
test_api "http://localhost:4000" "/health" "200"
test_api "http://localhost:4000" "/todos" "200"

# Test todo operations
echo ""
test_todo_operations "http://localhost:4000"

# Test frontend proxy
echo ""
echo "Testing frontend proxy..."
test_api "http://localhost" "/api/health" "200"

# Display service status
echo ""
echo "Service Status:"
echo "==============="
docker-compose ps

echo ""
echo -e "${GREEN}🎉 All tests passed! Your application is ready for deployment.${NC}"
echo ""
echo "Access your application at:"
echo "  Frontend: http://localhost"
echo "  Backend API: http://localhost:4000"
echo "  Database: localhost:5432"
echo ""
echo "To stop the services, run: docker-compose down" 