const express = require("express");
const { Sequelize, DataTypes } = require("sequelize");
const cors = require("cors");
require("dotenv").config();

const app = express();
const port = process.env.PORT || 4000;

// Middleware
app.use(cors());
app.use(express.json());

// Database connection
const sequelize = new Sequelize(
  process.env.POSTGRES_DB || "ecsdb",
  process.env.POSTGRES_USER || "ecsuser",
  process.env.POSTGRES_PASSWORD || "ecspassword",
  {
    host: process.env.POSTGRES_HOST || "db",
    dialect: "postgres",
    logging: false,
    pool: {
      max: 5,
      min: 0,
      acquire: 30000,
      idle: 10000
    }
  }
);

// Todo Model
const Todo = sequelize.define('Todo', {
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

// Database initialization
async function initializeDatabase() {
  try {
    await sequelize.authenticate();
    console.log('Database connection established successfully.');
    
    await sequelize.sync({ force: false }); // Don't force recreate tables
    console.log('Database synchronized.');
  } catch (error) {
    console.error('Unable to connect to the database:', error);
  }
}

// Initialize database
initializeDatabase();

// Routes

// Health check
app.get("/api/health", async (req, res) => {
  try {
    await sequelize.authenticate();
    res.json({ 
      status: "healthy", 
      message: "Backend is running and connected to database",
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({ 
      status: "unhealthy", 
      message: "Database connection failed", 
      error: error.message 
    });
  }
});

// Get all todos
app.get("/api/todos", async (req, res) => {
  try {
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

app.listen(port, () => {
  console.log(`Todo API server listening on port ${port}`);
  console.log(`Health check: http://localhost:${port}/api/health`);
});