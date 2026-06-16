from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    SUPABASE_URL: str
    SUPABASE_SECRET_KEY: str
    ENVIRONMENT: str = "local"

    class Config:
        env_file = ".env"
        extra = "ignore"

settings = Settings()
