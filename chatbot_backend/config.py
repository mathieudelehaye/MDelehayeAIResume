import os
from typing import List, Optional
from pydantic import BaseSettings, Field

class Settings(BaseSettings):
    """Application settings loaded from environment variables"""
    
    # OpenAI Configuration
    openai_api_key: str = Field(..., env="OPENAI_API_KEY")
    openai_model: str = Field("gpt-3.5-turbo", env="OPENAI_MODEL")
    openai_temperature: float = Field(0.7, env="OPENAI_TEMPERATURE")
    
    # Application Configuration
    app_name: str = Field("CV Chatbot API", env="APP_NAME")
    app_version: str = Field("2.0.0", env="APP_VERSION")
    environment: str = Field("development", env="ENVIRONMENT")
    log_level: str = Field("INFO", env="LOG_LEVEL")
    
    # API Configuration
    host: str = Field("0.0.0.0", env="HOST")
    port: int = Field(8000, env="PORT")
    
    # CORS Configuration
    allowed_origins: List[str] = Field(
        ["*"], 
        env="ALLOWED_ORIGINS"
    )
    
    # Database Configuration (Optional)
    db_host: str = Field("localhost", env="DB_HOST")
    db_port: int = Field(5432, env="DB_PORT")
    db_user: str = Field("postgres", env="DB_USER")
    db_password: str = Field("password", env="DB_PASSWORD")
    db_name: str = Field("cv_ai_logs", env="DB_NAME")
    database_url: Optional[str] = Field(None, env="DATABASE_URL")
    db_ssl_mode: str = Field("require", env="DB_SSL_MODE")
    
    # Redis Configuration (Optional)
    redis_url: str = Field("redis://localhost:6379", env="REDIS_URL")
    
    # Vector Database Configuration
    chroma_persist_directory: str = Field("./chroma_db", env="CHROMA_PERSIST_DIR")
    embedding_chunk_size: int = Field(500, env="EMBEDDING_CHUNK_SIZE")
    embedding_chunk_overlap: int = Field(50, env="EMBEDDING_CHUNK_OVERLAP")
    
    # Conversation Configuration
    max_conversation_memory: int = Field(10, env="MAX_CONVERSATION_MEMORY")
    max_message_length: int = Field(1000, env="MAX_MESSAGE_LENGTH")
    retrieval_top_k: int = Field(4, env="RETRIEVAL_TOP_K")
    
    class Config:
        env_file = ".env"
        case_sensitive = False

# Global settings instance
settings = Settings()

# Environment variable template for documentation
ENV_TEMPLATE = """
# Copy this to .env file and update the values

# OpenAI Configuration (Required)
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_MODEL=gpt-3.5-turbo
OPENAI_TEMPERATURE=0.7

# Application Configuration
APP_NAME=CV Chatbot API
APP_VERSION=2.0.0
ENVIRONMENT=development
LOG_LEVEL=INFO

# API Configuration
HOST=0.0.0.0
PORT=8000

# CORS Configuration (comma-separated)
ALLOWED_ORIGINS=http://localhost:3000,https://mathieu-cv.azurecontainerapps.io

# Database Configuration (Optional - for logging)
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your_password
DB_NAME=cv_ai_logs

# Redis Configuration (Optional)
REDIS_URL=redis://localhost:6379

# Vector Database Configuration
CHROMA_PERSIST_DIR=./chroma_db
EMBEDDING_CHUNK_SIZE=500
EMBEDDING_CHUNK_OVERLAP=50

# Conversation Configuration
MAX_CONVERSATION_MEMORY=10
MAX_MESSAGE_LENGTH=1000
RETRIEVAL_TOP_K=4

# PostgreSQL / Neon connection string (optional override)
DATABASE_URL=postgresql://user:password@your-neon-endpoint/db
DB_SSL_MODE=require
""" 