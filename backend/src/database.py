import os
from pathlib import Path
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

env_path = Path(__file__).parent.parent / ".env"
load_dotenv(dotenv_path=env_path)

DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    print(f"ERRO: DATABASE_URL nao encontrada!!! verifica esse arquivo aqui oh: {env_path}")
else:
    print(f"DATABASE_URL carregada com sucesso!")

engine = create_engine(
    DATABASE_URL, connect_args={"check_same_thread": False}, echo=True
)

SessionLocal = sessionmaker(autocommit = False, autoflush = False, bind = engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()