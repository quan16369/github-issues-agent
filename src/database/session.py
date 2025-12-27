import json
import os
from collections.abc import Generator
from contextlib import contextmanager

from google.cloud import secretmanager
from loguru import logger
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

from src.models.db_models import DBConfig
from src.utils.config import settings


def get_db_credentials_from_gcp(project_id: str, secret_id: str) -> dict:
    """Retrieve database credentials from GCP Secret Manager"""
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{project_id}/secrets/{secret_id}/versions/latest"
    response = client.access_secret_version(request={"name": name})
    secret_string = response.payload.data.decode("UTF-8")
    logger.info(f"Retrieved secret from GCP Secret Manager")
    return json.loads(secret_string)


class DB:
    def __init__(self, config: DBConfig | None = None) -> None:
        self.engine: Engine | None = None
        self.SessionLocal: sessionmaker | None = None
        self._init_db(config)

    def _init_db(self, config: DBConfig | None) -> None:
        if config is None:
            app_env = os.getenv("APP_ENV", "dev").lower()
            if app_env == "prod":
                creds = get_db_credentials_from_gcp(settings.GCP_PROJECT_ID, settings.SECRET_ID)
                config = DBConfig(
                    username=creds["username"],
                    password=creds["password"],
                    host=creds["host"],
                    port=int(creds["port"]),
                    dbname=creds["dbname"],
                )
            else:
                config = DBConfig(
                    username=settings.POSTGRES_USER,
                    password=settings.POSTGRES_PASSWORD,
                    host=settings.POSTGRES_HOST,
                    port=int(settings.POSTGRES_PORT),
                    dbname=settings.POSTGRES_DB,
                )

        logger.info(f"Connecting to DB with: {config}")
        db_url = config.build_url()
        logger.info(f"Database URL: {db_url}")
        self.engine = create_engine(db_url, echo=True)
        logger.info("DB engine created")
        self.SessionLocal = sessionmaker(bind=self.engine)
        logger.info("DB sessionmaker created")

    def get_session(self) -> Session:
        """Create and return a new Session instance."""
        if self.SessionLocal is None:
            raise RuntimeError("SessionLocal is not initialized.")
        return self.SessionLocal()

    @contextmanager
    def session_scope(self) -> Generator[Session, None, None]:
        """Provide a transactional scope around a series of operations."""
        session = self.get_session()
        try:
            yield session
            session.commit()
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()


# usage example
db = DB()
