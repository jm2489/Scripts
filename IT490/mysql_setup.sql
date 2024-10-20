-- Create a new MySQL user with access from any IP
CREATE USER IF NOT EXISTS 'rabbit'@'%' IDENTIFIED BY 'rabbitIT490!';

-- Grant all privileges to the user on the logindb database
GRANT ALL PRIVILEGES ON logindb.* TO 'rabbit'@'%' WITH GRANT OPTION;

-- Create the logindb database if it doesn't exist
CREATE DATABASE IF NOT EXISTS logindb;

-- Use the logindb database
USE logindb;

-- Create the users table with the specified schema
CREATE TABLE IF NOT EXISTS users (
    id INT NOT NULL AUTO_INCREMENT,
    username VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    last_login BIGINT NULL,
    PRIMARY KEY (id)
);

-- Create the sessions table with the specified schema
CREATE TABLE IF NOT EXISTS sessions (
    id INT NOT NULL AUTO_INCREMENT,
    username VARCHAR(255) NOT NULL,
    session_token VARCHAR(255) NOT NULL,
    created_at BIGINT DEFAULT (unix_timestamp()),
    expire_date BIGINT NOT NULL,
    PRIMARY KEY (id),
    UNIQUE(session_token)
);

-- Insert a default user and hashed password into the users table
INSERT INTO users (username,password)
VALUES ('steve', '$2y$10$iPNDJKXKUiT8OSYyXIACw.lTGJzD1CekSMfzW3o8k6yKWbyKHmLUq');

-- Apply the changes immediately
FLUSH PRIVILEGES;
