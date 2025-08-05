import React, { useState, useEffect } from "react";
import "./App.css";

function App() {
  const [todos, setTodos] = useState([]);
  const [newTodo, setNewTodo] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [backendStatus, setBackendStatus] = useState('Checking...');
  const [databaseStatus, setDatabaseStatus] = useState('Checking...');
  const [lastChecked, setLastChecked] = useState(null);

  // Use /api path for backend requests
  const API_BASE_URL = process.env.REACT_APP_API_URL || '/api';

  // Check backend and database status
  const checkStatus = async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/health`);
      const data = await response.json();
      
      if (response.ok) {
        setBackendStatus('Connected');
        setDatabaseStatus(data.services.database.status === 'connected' ? 'Connected' : 'Disconnected');
        setError(null);
      } else {
        setBackendStatus('Error');
        setDatabaseStatus('Unknown');
        setError(`Backend service error: ${data.services?.database?.error || 'Unknown error'}`);
      }
    } catch (err) {
      setBackendStatus('Connection Failed');
      setDatabaseStatus('Unknown');
      setError(`Cannot connect to backend: ${err.message}`);
    }
    setLastChecked(new Date().toLocaleTimeString());
  };

  // Fetch todos from backend
  const fetchTodos = async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/todos`);
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
      const response = await fetch(`${API_BASE_URL}/todos`, {
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
      const response = await fetch(`${API_BASE_URL}/todos/${id}`, {
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
      const response = await fetch(`${API_BASE_URL}/todos/${id}`, {
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
    checkStatus();
    fetchTodos();
    // Check status every 30 seconds
    const interval = setInterval(checkStatus, 30000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return <div className="App">Loading todos...</div>;
  }

  return (
    <div className="App">
      <header className="App-header">
        <h1>Todo App</h1>
        <p>Built with React + Node.js + PostgreSQL on ECS</p>
        
        <div className="status-container">
          <div className="status-item">
            <span className="status-label">Backend:</span>
            <span className={`status-value ${backendStatus.toLowerCase().replace(' ', '-')}`}>
              {backendStatus}
            </span>
          </div>
          <div className="status-item">
            <span className="status-label">Database:</span>
            <span className={`status-value ${databaseStatus.toLowerCase().replace(' ', '-')}`}>
              {databaseStatus}
            </span>
          </div>
          {lastChecked && (
            <div className="status-item">
              <span className="status-label">Last Checked:</span>
              <span className="status-value">{lastChecked}</span>
            </div>
          )}
        </div>
      </header>

      {error && (
        <div className="error">
          <h3>Error</h3>
          <p>{error}</p>
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
          />
          <button type="submit" className="add-button">
            Add Todo
          </button>
        </form>

        <div className="todo-list">
          {todos.length === 0 ? (
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