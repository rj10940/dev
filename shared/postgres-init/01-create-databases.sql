-- Cloudways Developer Environment - PostgreSQL Initialization
-- This script runs on first container startup

-- Create template database for event service
CREATE DATABASE cw_template_events;

-- Create extension for UUID generation
\c cw_template_events;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Log completion
SELECT 'PostgreSQL initialization complete' AS status;

