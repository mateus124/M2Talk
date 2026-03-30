from fastapi import WebSocket, WebSocketDisconnect

class ConnectionManager:
    def __init__(self):
        self.active_connections = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        print(f"Conectado: {len(self.active_connections)} conexões")

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)
        print(f"Desconectado: {len(self.active_connections)} conexões")

    async def send_message(self, message: str, websocket: WebSocket):
        await websocket.send_text(message)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            await connection.send_text(message)


manager = ConnectionManager()


async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            
            print(f"Recebido: {data}")
            
            response = f"Echo: {data}"
            await manager.send_message(response, websocket)

    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as e:
        print(f"Erro: {e}")
        manager.disconnect(websocket)