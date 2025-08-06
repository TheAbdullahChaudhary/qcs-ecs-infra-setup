# Health Endpoints Reference

This document lists all health endpoints for the 3-tier application.

## 🏥 Health Endpoints

### Local Development

| Service | Endpoint | Description | Expected Response |
|---------|----------|-------------|-------------------|
| Frontend | `http://localhost/health` | Nginx health check | `healthy` |
| Backend | `http://localhost:4000/health` | Backend API health | JSON with status info |
| API Proxy | `http://localhost/api/health` | Backend via Nginx proxy | JSON with status info |
| Database | `localhost:5432` | PostgreSQL connection | Connection established |

### ECS Production

| Service | Endpoint | Description | Expected Response |
|---------|----------|-------------|-------------------|
| Frontend | `http://<alb-dns>/health` | Nginx health check | `healthy` |
| Backend | `http://<alb-dns>/api/health` | Backend API health | JSON with status info |
| Database | Internal only | PostgreSQL connection | Connection established |

## 🔍 Health Check Details

### Frontend Health Check
- **Path**: `/health`
- **Method**: GET
- **Response**: `healthy` (plain text)
- **Purpose**: Verify Nginx is running and serving requests

### Backend Health Check
- **Path**: `/health`
- **Method**: GET
- **Response**: JSON with detailed status information
- **Purpose**: Verify backend API and database connectivity

Example Response:
```json
{
  "status": "healthy",
  "timestamp": "2025-08-06T15:00:46.238Z",
  "services": {
    "database": {
      "status": "connected",
      "responseTime": "1ms",
      "host": "db",
      "database": "ecsdb",
      "port": "5432"
    },
    "api": {
      "status": "running",
      "port": 4000,
      "environment": "production"
    }
  }
}
```

### Database Health Check
- **Command**: `pg_isready -U ecsuser -d ecsdb`
- **Purpose**: Verify PostgreSQL is accepting connections
- **Used in**: Container health checks and ECS service health monitoring

## 🚨 Troubleshooting

### If Frontend Health Check Fails
1. Check if Nginx container is running
2. Verify nginx.conf configuration
3. Check container logs: `docker-compose logs frontend`

### If Backend Health Check Fails
1. Check if backend container is running
2. Verify database connection
3. Check container logs: `docker-compose logs backend`

### If Database Health Check Fails
1. Check if database container is running
2. Verify PostgreSQL configuration
3. Check container logs: `docker-compose logs db`

## 📋 Testing Commands

### Local Testing
```powershell
# Test frontend health
Invoke-WebRequest -Uri "http://localhost/health"

# Test backend health
Invoke-WebRequest -Uri "http://localhost:4000/health"

# Test API proxy
Invoke-WebRequest -Uri "http://localhost/api/health"

# Test database connection
docker-compose exec db pg_isready -U ecsuser -d ecsdb
```

### ECS Testing
```powershell
# Test frontend health
Invoke-WebRequest -Uri "http://<your-alb-dns>/health"

# Test backend health
Invoke-WebRequest -Uri "http://<your-alb-dns>/api/health"
```

## 🔧 Load Balancer Configuration

### ALB Health Check Settings
- **Protocol**: HTTP
- **Port**: 80 (frontend), 4000 (backend)
- **Path**: `/health`
- **Healthy threshold**: 2
- **Unhealthy threshold**: 2
- **Timeout**: 5 seconds
- **Interval**: 30 seconds

### ECS Health Check Settings
- **Command**: See individual service configurations
- **Interval**: 30 seconds
- **Timeout**: 5 seconds
- **Retries**: 3
- **Start period**: 60 seconds

## 📊 Monitoring

### CloudWatch Logs
- **Frontend**: `/ecs/frontend`
- **Backend**: `/ecs/backend`
- **Database**: `/ecs/database`

### Health Check Metrics
- ALB target health metrics
- ECS service health metrics
- Container health check status

## 🎯 Success Criteria

All health endpoints should return:
- ✅ Frontend: HTTP 200 with "healthy" response
- ✅ Backend: HTTP 200 with JSON status
- ✅ Database: Connection established
- ✅ API Proxy: HTTP 200 with JSON status

If any endpoint fails, check the corresponding service logs and configuration. 