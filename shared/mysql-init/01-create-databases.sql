-- Cloudways Developer Environment - MySQL Initialization
-- This script runs on first container startup

-- Create a template database that can be cloned for each developer
CREATE DATABASE IF NOT EXISTS `cw_template_platform` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `cw_template_middleware` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Grant privileges
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

-- Log completion
SELECT 'MySQL initialization complete' AS status;

