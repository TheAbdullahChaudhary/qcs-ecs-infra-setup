# 3-Tier ECS Application

A modern 3-tier web application built with React, Node.js, and PostgreSQL, designed to run on AWS ECS with proper networking, security, and scalability.

## Architecture

```
Internet → ALB → Frontend (Public Subnet) → Backend (Private Subnet) → PostgreSQL (RDS)
```

### Components

- **Frontend**: React application served by Nginx
- **Backend**: Node.js/Express API with Sequelize ORM
- **Database**: PostgreSQL on RDS
- **Infrastructure**: ECS Fargate, Application Load Balancer, VPC with public/private subnets
- **Security**: AWS Secrets Manager for database credentials, security groups, IAM roles

## Features

- ✅ **Real-time Status Monitoring**: Frontend displays backend and database connection status
- ✅ **Todo Management**: Full CRUD operations for todo items
- ✅ **Health Checks**: Comprehensive health monitoring for all services
- ✅ **Secure Credentials**: Database credentials stored in AWS Secrets Manager
- ✅ **High Availability**: Multi-AZ deployment with load balancing
- ✅ **Modern UI**: Responsive design with real-time status indicators
- ✅ **Containerized**: Docker-based deployment with optimized images

## Application Structure

```
3-tier-app/
├── frontend/                 # React application
│   ├── src/
│   │   ├── App.js           # Main React component
│   │   └── App.css          # Styling
│   ├── Dockerfile           # Multi-stage Docker build
│   ├── nginx.conf           # Nginx configuration
│   └── package.json
├── backend/                  # Node.js API
│   ├── index.js             # Express server with Sequelize
│   ├── Dockerfile           # Production Docker image
│   └── package.json
├── MANUAL_SETUP_GUIDE.md    # Complete manual setup instructions
├── setup-variables.sh       # Environment variables setup script
└── README.md               # This file
```

## Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Docker installed locally
- Node.js 18+ (for local development)

### Local Development

1. **Start the backend**:
   ```bash
   cd backend
   npm install
   npm start
   ```

2. **Start the frontend**:
   ```bash
   cd frontend
   npm install
   npm start
   ```

3. **Set up PostgreSQL** (local or RDS):
   - Create a database named `ecsdb`
   - Update backend environment variables

### Production Deployment

Follow the complete manual setup guide in `MANUAL_SETUP_GUIDE.md` for step-by-step instructions to deploy on AWS ECS.

## Key Features

### Frontend Features
- **Real-time Status Display**: Shows backend and database connection status
- **Responsive Design**: Works on desktop and mobile devices
- **Modern UI**: Beautiful gradient design with glassmorphism effects
- **Error Handling**: Comprehensive error display and recovery
- **Auto-refresh**: Status checks every 30 seconds

### Backend Features
- **RESTful API**: Complete CRUD operations for todos
- **Database Integration**: Sequelize ORM with PostgreSQL
- **Health Monitoring**: Detailed health check endpoints
- **Error Handling**: Comprehensive error handling and logging
- **Security**: Environment-based configuration with secrets management

### Infrastructure Features
- **Multi-tier Security**: Public/private subnet separation
- **Load Balancing**: Application Load Balancer with health checks
- **Auto-scaling**: ECS services with configurable scaling
- **Monitoring**: CloudWatch logs and metrics
- **Secrets Management**: Secure credential storage

## API Endpoints

### Health Checks
- `GET /health` - Overall application health
- `GET /health/database` - Database connection status

### Todo Operations
- `GET /todos` - Get all todos
- `POST /todos` - Create new todo
- `GET /todos/:id` - Get specific todo
- `PATCH /todos/:id` - Update todo
- `DELETE /todos/:id` - Delete todo

## Environment Variables

### Backend
- `POSTGRES_HOST` - Database host
- `POSTGRES_PORT` - Database port (default: 5432)
- `POSTGRES_DB` - Database name
- `POSTGRES_USER` - Database username (from Secrets Manager)
- `POSTGRES_PASSWORD` - Database password (from Secrets Manager)
- `NODE_ENV` - Environment (development/production)
- `PORT` - Server port (default: 4000)

### Frontend
- `REACT_APP_API_URL` - Backend API URL (default: /api)

## Security Considerations

1. **Network Security**: Backend runs in private subnets
2. **Credential Management**: Database credentials in AWS Secrets Manager
3. **IAM Roles**: Least privilege access for ECS tasks
4. **Security Groups**: Minimal required port access
5. **HTTPS Ready**: ALB configured for SSL termination

## Monitoring and Logging

- **CloudWatch Logs**: All container logs centralized
- **Health Checks**: Application and load balancer health monitoring
- **Metrics**: ECS service metrics and database monitoring
- **Alerts**: Configurable CloudWatch alarms

## Troubleshooting

### Common Issues

1. **Database Connection Failed**
   - Check security group rules
   - Verify Secrets Manager permissions
   - Confirm database endpoint

2. **Frontend Not Loading**
   - Check ALB health checks
   - Verify nginx configuration
   - Check container logs

3. **Backend API Errors**
   - Check database connectivity
   - Verify environment variables
   - Review application logs

### Debug Commands

```bash
# Check service status
aws ecs describe-services --cluster ecs-app-cluster --services ecs-backend-service

# View logs
aws logs tail /ecs/backend --follow

# Check target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally and in staging
5. Submit a pull request

## License

This project is licensed under the MIT License.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review the manual setup guide
3. Check AWS documentation for ECS, RDS, and VPC
4. Open an issue in the repository 