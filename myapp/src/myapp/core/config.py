#Central place for ALL environment variables
#Why this matters:
#    No scattered os.getenv()
#    Type-safe config
#    Works across dev/staging/prod
#Use pydantic-settings
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    app_name: str = "MyApp"
    app_env: str = Field("dev", alias="APP_ENV")

    db_host: str = Field("db", alias="DB_HOST")
    db_port: int = Field(5432, alias="DB_PORT")
    db_name: str = Field("mydb", alias="DB_NAME")
    db_user: str = Field("myuser", alias="DB_USER")
    db_password: str = Field("mypassword", alias="DB_PASSWORD")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

settings = Settings()
