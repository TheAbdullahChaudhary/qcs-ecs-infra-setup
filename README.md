# Todo App - 3-Tier Architecture on AWS ECS

A modern Todo application built with React, Node.js, and PostgreSQL, deployed on AWS ECS with Jenkins CI/CD pipeline.

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   React App     │    │   Node.js API   │    │   PostgreSQL    │
│   (Frontend)    │◄──►│   (Backend)     │◄──►│   (Database)    │
│   Port: 80      │    │   Port: 4000    │    │   Port: 5432    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## ✨ Features

### Frontend (React)
- ✅ Add new todos
- ✅ Mark todos as complete/incomplete
- ✅ Delete todos
- ✅ Real-time updates
- ✅ Modern, responsive UI
- ✅ Error handling

### Backend (Node.js + Express)
- ✅ RESTful API
- ✅ PostgreSQL database integration
- ✅ CORS enabled
- ✅ Input validation
- ✅ Error handling
- ✅ Health check endpoint

### Database (PostgreSQL)
- ✅ Todo items with text and completion status
- ✅ Automatic timestamps
- ✅ Data persistence

## 🚀 Quick Start (Local Development)

### Prerequisites
- Docker and Docker Compose
- Node.js (for local development)

### Running Locally

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd 3-tier-app
   ```

2. **Start all services**
   ```bash
   cd backend
   docker-compose up --build
   ```

3. **Access the application**
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:4000
   - Health Check: http://localhost:4000/api/health

## 🏗️ Infrastructure (AWS ECS)

### Components
- **VPC**: Custom VPC with public/private subnets
- **ECS Cluster**: EC2 launch type for applications, Fargate for Jenkins
- **EFS**: Persistent storage for Jenkins
- **ECR**: Docker image repositories
- **Jenkins**: CI/CD pipeline on Fargate
- **Security Groups**: Network isolation

### Deployment
1. **Apply Terraform**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

2. **Build and deploy via Jenkins**
   - Jenkins will automatically build Docker images
   - Push images to ECR
   - Deploy to ECS services

## 📁 Project Structure

```
3-tier-app/
├── frontend/                 # React Todo App
│   ├── src/
│   │   ├── App.js           # Main React component
│   │   └── App.css          # Styles
│   ├── public/
│   ├── package.json
│   └── Dockerfile
├── backend/                  # Node.js API
│   ├── index.js             # Express server
│   ├── package.json
│   ├── Dockerfile
│   └── docker-compose.yml   # Local development
├── jenkins/                  # CI/CD
│   ├── Dockerfile
│   └── Jenkinsfile
├── modules/                  # Terraform modules
│   ├── vpc/
│   ├── ecs-cluster/
│   ├── efs/
│   ├── jenkins/
│   ├── frontend/
│   └── backend/
├── main.tf                   # Root Terraform
├── variables.tf
└── README.md
```

## 🔧 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/health` | Health check |
| GET | `/api/todos` | Get all todos |
| POST | `/api/todos` | Create new todo |
| GET | `/api/todos/:id` | Get single todo |
| PATCH | `/api/todos/:id` | Update todo |
| DELETE | `/api/todos/:id` | Delete todo |

### Example API Usage

```bash
# Get all todos
curl http://localhost:4000/api/todos

# Create a todo
curl -X POST http://localhost:4000/api/todos \
  -H "Content-Type: application/json" \
  -d '{"text": "Buy groceries"}'

# Update a todo
curl -X PATCH http://localhost:4000/api/todos/1 \
  -H "Content-Type: application/json" \
  -d '{"completed": true}'

# Delete a todo
curl -X DELETE http://localhost:4000/api/todos/1
```

## 🐳 Docker Images

- **Frontend**: React app served by Nginx
- **Backend**: Node.js Express API
- **Database**: PostgreSQL (local development)
- **Jenkins**: Jenkins with Docker and AWS CLI

## 🔒 Security

- All services run in private subnets
- Security groups control network access
- IAM roles for service permissions
- EFS encryption for Jenkins persistence

## 📊 Monitoring

- CloudWatch logs for all containers
- Health check endpoints
- Error handling and logging

## 🚀 CI/CD Pipeline

1. **Code Push** → Jenkins detects changes
2. **Build** → Docker images for frontend/backend
3. **Push** → Images pushed to ECR
4. **Deploy** → ECS services updated with new images

## 🛠️ Development

### Adding Features
1. Update frontend React components
2. Add backend API endpoints
3. Update database schema if needed
4. Test locally with Docker Compose
5. Push to trigger CI/CD pipeline

### Environment Variables
- `POSTGRES_HOST`: Database host
- `POSTGRES_DB`: Database name
- `POSTGRES_USER`: Database user
- `POSTGRES_PASSWORD`: Database password
- `REACT_APP_API_URL`: Backend API URL

## 📝 License

This project is for educational purposes and demonstrates a complete 3-tier application deployment on AWS ECS. 