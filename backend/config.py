from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+asyncpg://halalbites:halalbites@localhost:5432/halalbites"
    openai_api_key: str = ""
    gemini_api_key: str = ""
    ai_provider: str = "openai"  # "openai" or "gemini"
    cors_origins: list[str] = ["*"]
    debug: bool = False


settings = Settings()
