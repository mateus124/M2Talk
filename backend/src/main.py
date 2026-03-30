from fastapi import FastAPI, WebSocket
from sockets.ws import websocket_endpoint

app = FastAPI()


@app.get("/ping")
async def ping():
    return {"message": "server ok"}


@app.websocket("/ws")
async def websocket_route(websocket: WebSocket):
    await websocket_endpoint(websocket)