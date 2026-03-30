from fastapi import FastAPI, WebSocket
from sockets.ws import websocket_endpoint
from database import Base, engine

app = FastAPI()


@app.on_event("startup")
def startup_event():
    print("inicializando o banco de dados (é sqlite kk)...")
    Base.metadata.create_all(bind=engine)
    print("banco de dados pronto para uso!!!!!! hehe")

@app.get("/ping")
async def ping():
    return {"message": "server ok"}


@app.websocket("/ws")
async def websocket_route(websocket: WebSocket):
    await websocket_endpoint(websocket)