-- Database initialization script for ECS Todo Application
-- This script runs when the PostgreSQL container starts for the first time

-- Create the database if it doesn't exist (usually handled by POSTGRES_DB env var)
-- SELECT 'CREATE DATABASE ecsdb' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ecsdb')\gexec

-- Connect to the database
\c ecsdb;

-- Create extensions if needed
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create a table to track database initialization
CREATE TABLE IF NOT EXISTS db_init (
    id SERIAL PRIMARY KEY,
    init_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    version VARCHAR(10) DEFAULT '1.0.0',
    description TEXT DEFAULT 'ECS Todo App Database Initialization'
);

-- Insert initialization record
INSERT INTO db_init (description) VALUES ('ECS Todo App Database initialized successfully');

-- Create indexes for better performance (will be created by Sequelize, but good to have)
-- These will be created automatically by Sequelize when the Todo model is synced

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON DATABASE ecsdb TO ecsuser;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ecsuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ecsuser;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ecsuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ecsuser;

-- Log successful initialization
SELECT 'ECS Todo App Database initialized successfully at ' || CURRENT_TIMESTAMP as status; 