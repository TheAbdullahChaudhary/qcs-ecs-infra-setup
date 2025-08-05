const express = require("express");
const { Sequelize, DataTypes } = require("sequelize");
const cors = require("cors");
const AWS = require("aws-sdk");
require("dotenv").config();

const app = express();
const port = process.env.PORT || 4000;

// Configure AWS SDK
AWS.config.update({
  region: process.env.AWS_REGION || 'us-east-1'
});

const secretsManager = new AWS.SecretsManager();

// Middleware
app.use(cors());
app.use(express.json());

let sequelize;
let Todo;
let dbCredentials = null;

// Function to get database credentials from Secrets Manager
async function getDatabaseCredentials() {
  try {
    const secretName = process.env.DB_SECRET_NAME || 'ecs-app-db-credentials';
    const result = await secretsManager.getSecretValue({ SecretId: secretName }).promise();
    const secret = JSON.parse(result.SecretString);
    
    dbCredentials = {
      host: secret.host,
      database: secret.dbname,
      username: secret.username,
      password: secret.password,
      port: secret.port || 5432
    };
    
    console.log('Database credentials retrieved from Secrets Manager');
    return dbCredentials;
  } catch (error) {
    console.error('Error retrieving database credentials:', error);
    // Fallback to environment variables for local development
    dbCredentials = {
      host: process.env.POSTGRES_HOST || "localhost",
      database: process.env.POSTGRES_DB || "ecsdb",
      username: process.env.POSTGRES_USER || "ecsuser",
      password: process.env.POSTGRES_PASSWORD || "ecspassword",
      port: process.env.POSTGRES_PORT || 5432
    };
    return dbCredentials;
  }
}

// Initialize database connection
async function initializeDatabase() {
  try {
    const credentials = await getDatabaseCredentials();
    
    sequelize = new Sequelize(
      credentials.database,
      credentials.username,
      credentials.password,
      {
        host: credentials.host,
        port: credentials.port,
        dialect: "postgres",
        logging: console.log,
        pool: {
          max: 5,
          min: 0,
          acquire: 30000,
          idle: 10000
        }
      }
    );

    await sequelize.authenticate();
    console.log('Database connection established successfully.');
    
    // Define Todo model after sequelize is initialized
    Todo = sequelize.define('Todo', {
      id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true
      },
      text: {
        type: DataTypes.STRING,
        allowNull: false
      },
      completed: {
        type: DataTypes.BOOLEAN,
        defaultValue: false
      }
    }, {
      timestamps: true
    });
    
    await sequelize.sync({ force: false });
    console.log('Database synchronized.');
    
    return true;
  } catch (error) {
    console.error('Unable to connect to the database:', error);
    return false;
  }
}

// Health check endpoints
app.get('/health', async (req, res) => {
  try {
    if (!sequelize) {
      throw new Error('Database not initialized');
    }
    await sequelize.authenticate();
    res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      services: {
        database: {
          status: 'connected',
          host: dbCredentials?.host || 'unknown',
          database: dbCredentials?.database || 'unknown',
          responseTime: '< 100ms'
        },
        api: {
          status: 'running',
          port: port,
          environment: process.env.NODE_ENV || 'development'
        }
      }
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      services: {
        database: {
          status: 'disconnected',
          error: error.message,
          host: dbCredentials?.host || 'unknown'
        },
        api: {
          status: 'running',
          port: port
        }
      }
    });
  }
});

// Detailed database status
app.get('/health/database', async (req, res) => {
  try {
    if (!sequelize) {
      throw new Error('Database not initialized');
    }
    
    const dbStart = Date.now();
    await sequelize.authenticate();
    const dbEnd = Date.now();

    res.status(200).json({
      status: 'connected',
      responseTime: `${dbEnd - dbStart}ms`,
      details: {
        host: dbCredentials?.host || 'unknown',
        database: dbCredentials?.database || 'unknown',
        username: dbCredentials?.username || 'unknown',
        port: dbCredentials?.port || 5432,
        maxConnections: sequelize.config.pool.max,
        usingSecretsManager: !!process.env.DB_SECRET_NAME
      }
    });
  } catch (error) {
    res.status(503).json({
      status: 'disconnected',
      error: error.message,
      details: {
        host: dbCredentials?.host || 'unknown',
        database: dbCredentials?.database || 'unknown',
        usingSecretsManager: !!process.env.DB_SECRET_NAME
      }
    });
  }
});

// API Health check
app.get("/api/health", async (req, res) => {
  try {
    if (!sequelize) {
      throw new Error('Database not initialized');
    }
    await sequelize.authenticate();
    res.json({ 
      status: "healthy", 
      message: "Backend is running and connected to database",
      timestamp: new Date().toISOString(),
      database: {
        status: "connected",
        host: dbCredentials?.host || 'unknown',
        database: dbCredentials?.database || 'unknown'
      }
    });
  } catch (error) {
    res.status(500).json({ 
      status: "unhealthy", 
      message: "Database connection failed", 
      error: error.message,
      database: {
        status: "disconnected",
        host: dbCredentials?.host || 'unknown'
      }
    });
  }
});

// Routes

// Get all todos
app.get("/api/todos", async (req, res) => {
  try {
    if (!Todo) {
      throw new Error('Database not initialized');
    }
    const todos = await Todo.findAll({
      order: [['createdAt', 'DESC']]
    });
    res.json(todos);
  } catch (error) {
    console.error('Error fetching todos:', error);
    res.status(500).json({ error: "Failed to fetch todos" });
  }
});

// Create new todo
app.post("/api/todos", async (req, res) => {
  try {
    if (!Todo) {
      throw new Error('Database not initialized');
    }
    
    const { text } = req.body;
    
    if (!text || text.trim() === '') {
      return res.status(400).json({ error: "Todo text is required" });
    }

    const todo = await Todo.create({
      text: text.trim(),
      completed: false
    });

    res.status(201).json(todo);
  } catch (error) {
    console.error('Error creating todo:', error);
    res.status(500).json({ error: "Failed to create todo" });
  }
});

// Update todo
app.patch("/api/todos/:id", async (req, res) => {
  try {
    if (!Todo) {
      throw new Error('Database not initialized');
    }
    
    const { id } = req.params;
    const { text, completed } = req.body;

    const todo = await Todo.findByPk(id);
    
    if (!todo) {
      return res.status(404).json({ error: "Todo not found" });
    }

    // Update only provided fields
    if (text !== undefined) {
      todo.text = text.trim();
    }
    if (completed !== undefined) {
      todo.completed = completed;
    }

    await todo.save();
    res.json(todo);
  } catch (error) {
    console.error('Error updating todo:', error);
    res.status(500).json({ error: "Failed to update todo" });
  }
});

// Delete todo
app.delete("/api/todos/:id", async (req, res) => {
  try {
    if (!Todo) {
      throw new Error('Database not initialized');
    }
    
    const { id } = req.params;
    
    const todo = await Todo.findByPk(id);
    
    if (!todo) {
      return res.status(404).json({ error: "Todo not found" });
    }

    await todo.destroy();
    res.status(204).send();
  } catch (error) {
    console.error('Error deleting todo:', error);
    res.status(500).json({ error: "Failed to delete todo" });
  }
});

// Get single todo
app.get("/api/todos/:id", async (req, res) => {
  try {
    if (!Todo) {
      throw new Error('Database not initialized');
    }
    
    const { id } = req.params;
    
    const todo = await Todo.findByPk(id);
    
    if (!todo) {
      return res.status(404).json({ error: "Todo not found" });
    }

    res.json(todo);
  } catch (error) {
    console.error('Error fetching todo:', error);
    res.status(500).json({ error: "Failed to fetch todo" });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: "Something went wrong!" });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: "Route not found" });
});

// Start server after database initialization
async function startServer() {
  console.log('Starting server...');
  const dbInitialized = await initializeDatabase();
  
  app.listen(port, () => {
    console.log(`Todo API server listening on port ${port}`);
    console.log(`Health check: http://localhost:${port}/api/health`);
    console.log(`Database status: ${dbInitialized ? 'Connected' : 'Failed'}`);
  });
}

startServer();