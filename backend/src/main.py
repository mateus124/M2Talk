from contextlib import asynccontextmanager

from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from sockets.ws import websocket_endpoint
from database import Base, engine, SessionLocal
from api import router
import models
from services.group_service import GroupService



@asynccontextmanager
async def lifespan(app: FastAPI):
    print("inicializando o banco de dados (é sqlite kk)...")
    Base.metadata.create_all(bind=engine)
    # Não criar grupos padrão automaticamente
    print("banco de dados pronto para uso!!!!!! hehe")
    yield


app = FastAPI(title="M2Talk API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
@app.get("/ping")
async def ping():
    return {"message": "server ok"}


app.include_router(router)


@app.websocket("/ws")
async def websocket_route(websocket: WebSocket):
    token = websocket.query_params.get("token")
    await websocket_endpoint(websocket, token)