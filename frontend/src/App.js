import React, { useState, useEffect } from "react";
import "./App.css";

function App() {
  const [todos, setTodos] = useState([]);
  const [newTodo, setNewTodo] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [backendStatus, setBackendStatus] = useState({
    status: 'checking',
    message: 'Checking backend connection...',
    database: { status: 'unknown' }
  });
  const [databaseStatus, setDatabaseStatus] = useState({
    status: 'checking',
    message: 'Checking database connection...',
    details: {}
  });

  // Use environment variable or default to relative path for ALB
  const API_BASE_URL = process.env.REACT_APP_API_URL || '';

  // Check backend connection and status
  const checkBackendStatus = async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/health`);
      const data = await response.json();
      
      if (response.ok) {
        setBackendStatus({
          status: 'healthy',
          message: 'Backend is running and connected',
          database: data.database || { status: 'unknown' },
          timestamp: data.timestamp
        });
        setError(null);
      } else {
        setBackendStatus({
          status: 'unhealthy',
          message: data.message || 'Backend service error',
          database: data.database || { status: 'disconnected' },
          error: data.error
        });
      }
    } catch (err) {
      setBackendStatus({
        status: 'disconnected',
        message: 'Cannot connect to backend',
        database: { status: 'unknown' },
        error: err.message
      });
    }
  };

  // Check detailed database status
  const checkDatabaseStatus = async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/health/database`);
      const data = await response.json();
      
      if (response.ok) {
        setDatabaseStatus({
          status: 'connected',
          message: `Connected to PostgreSQL (${data.responseTime})`,
          details: data.details || {},
          responseTime: data.responseTime
        });
      } else {
        setDatabaseStatus({
          status: 'disconnected',
          message: 'Database connection failed',
          details: data.details || {},
          error: data.error
        });
      }
    } catch (err) {
      setDatabaseStatus({
        status: 'disconnected',
        message: 'Cannot check database status',
        details: {},
        error: err.message
      });
    }
  };

  // Fetch todos from backend
  const fetchTodos = async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/todos`);
      if (!response.ok) {
        throw new Error('Failed to fetch todos');
      }
      const data = await response.json();
      setTodos(data);
      setLoading(false);
      setError(null);
    } catch (err) {
      setError(`Error fetching todos: ${err.message}`);
      setLoading(false);
    }
  };

  // Add new todo
  const addTodo = async (e) => {
    e.preventDefault();
    if (!newTodo.trim()) return;

    try {
      const response = await fetch(`${API_BASE_URL}/api/todos`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ text: newTodo }),
      });

      if (!response.ok) {
        throw new Error('Failed to add todo');
      }

      const addedTodo = await response.json();
      setTodos([addedTodo, ...todos]);
      setNewTodo("");
    } catch (err) {
      setError(err.message);
    }
  };

  // Toggle todo completion
  const toggleTodo = async (id, completed) => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/todos/${id}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ completed: !completed }),
      });

      if (!response.ok) {
        throw new Error('Failed to update todo');
      }

      setTodos(todos.map(todo =>
        todo.id === id ? { ...todo, completed: !completed } : todo
      ));
    } catch (err) {
      setError(err.message);
    }
  };

  // Delete todo
  const deleteTodo = async (id) => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/todos/${id}`, {
        method: 'DELETE',
      });

      if (!response.ok) {
        throw new Error('Failed to delete todo');
      }

      setTodos(todos.filter(todo => todo.id !== id));
    } catch (err) {
      setError(err.message);
    }
  };

  useEffect(() => {
    checkBackendStatus();
    checkDatabaseStatus();
    fetchTodos();
    
    // Check status every 30 seconds
    const interval = setInterval(() => {
      checkBackendStatus();
      checkDatabaseStatus();
    }, 30000);
    
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="App">
        <div className="loading">Loading application...</div>
      </div>
    );
  }

  return (
    <div className="App">
      <header className="App-header">
        <h1>3-Tier Todo App</h1>
        <p>React Frontend + Node.js Backend + PostgreSQL on AWS ECS</p>
        
        {/* Service Status Dashboard */}
        <div className="status-dashboard">
          <div className={`status-card backend ${backendStatus.status}`}>
            <h3>Backend Service</h3>
            <div className={`status-indicator ${backendStatus.status}`}>
              {backendStatus.status === 'healthy' ? '✅' : 
               backendStatus.status === 'unhealthy' ? '⚠️' : 
               backendStatus.status === 'disconnected' ? '❌' : '🔄'}
            </div>
            <p>{backendStatus.message}</p>
            {backendStatus.error && <small>Error: {backendStatus.error}</small>}
          </div>
          
          <div className={`status-card database ${databaseStatus.status}`}>
            <h3>PostgreSQL Database</h3>
            <div className={`status-indicator ${databaseStatus.status}`}>
              {databaseStatus.status === 'connected' ? '✅' : 
               databaseStatus.status === 'disconnected' ? '❌' : '🔄'}
            </div>
            <p>{databaseStatus.message}</p>
            {databaseStatus.details.host && (
              <small>Host: {databaseStatus.details.host}:{databaseStatus.details.port}</small>
            )}
            {databaseStatus.details.usingSecretsManager && (
              <small>🔐 Using AWS Secrets Manager</small>
            )}
            {databaseStatus.error && <small>Error: {databaseStatus.error}</small>}
          </div>
        </div>
      </header>

      {error && (
        <div className="error">
          <h3>Application Error</h3>
          <p>{error}</p>
          <button onClick={() => setError(null)}>Dismiss</button>
        </div>
      )}

      <main>
        <form onSubmit={addTodo} className="todo-form">
          <input
            type="text"
            value={newTodo}
            onChange={(e) => setNewTodo(e.target.value)}
            placeholder="Add a new todo..."
            className="todo-input"
            disabled={backendStatus.status !== 'healthy'}
          />
          <button 
            type="submit" 
            className="add-button"
            disabled={backendStatus.status !== 'healthy'}
          >
            Add Todo
          </button>
        </form>

        <div className="todo-list">
          {backendStatus.status !== 'healthy' ? (
            <div className="service-unavailable">
              <h3>Service Unavailable</h3>
              <p>Please check the backend and database status above.</p>
            </div>
          ) : todos.length === 0 ? (
            <p className="no-todos">No todos yet. Add one above!</p>
          ) : (
            todos.map((todo) => (
              <div key={todo.id} className={`todo-item ${todo.completed ? 'completed' : ''}`}>
                <input
                  type="checkbox"
                  checked={todo.completed}
                  onChange={() => toggleTodo(todo.id, todo.completed)}
                  className="todo-checkbox"
                />
                <span className="todo-text">{todo.text}</span>
                <button
                  onClick={() => deleteTodo(todo.id)}
                  className="delete-button"
                >
                  Delete
                </button>
              </div>
            ))
          )}
        </div>
      </main>
    </div>
  );
}

export default App;