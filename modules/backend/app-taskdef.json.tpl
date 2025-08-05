[
  {
    "name": "backend",
    "image": "941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-backend:latest",
    "essential": true,
    "portMappings": [
      { "containerPort": 4000, "protocol": "tcp" }
    ],
    "environment": [
      { "name": "PORT", "value": "4000" },
      { "name": "NODE_ENV", "value": "production" },
      { "name": "POSTGRES_HOST", "value": "${postgres_host}" },
      { "name": "POSTGRES_DB", "value": "ecsdb" },
      { "name": "POSTGRES_USER", "value": "ecsuser" },
      { "name": "POSTGRES_PASSWORD", "value": "ecspassword123!" }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/backend",
        "awslogs-region": "us-east-1",
        "awslogs-stream-prefix": "ecs",
        "awslogs-create-group": "true"
      }
    },
    "healthCheck": {
      "command": ["CMD-SHELL", "curl -f http://localhost:4000/api/health || exit 1"],
      "interval": 30,
      "timeout": 5,
      "retries": 3,
      "startPeriod": 60
    }
  }
]