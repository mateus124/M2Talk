# M2Talk

Projeto da disciplina de Sistemas Distribuidos.

- Numero da lista: 29
- Integrantes: Mateus Alves e Mateus Dodó

## Sobre a aplicacao

O M2Talk e uma aplicacao de chat em tempo real com suporte a:

- Conversas privadas
- Conversas em grupo
- Sincronizacao de mensagens via WebSocket

## Como executar

### Frontend (React)

```bash
cd frontend
npm install
npm run dev
```

### Backend (Python)

```bash
cd backend
uv venv
```

Ative o ambiente virtual:

- Linux/macOS:

```bash
source .venv/bin/activate
```

- Windows (PowerShell):

```powershell
.\venv\Scripts\Activate.ps1
```

Instale as dependencias e inicie o servidor:

```bash
uv sync
fastapi dev src/main.py
```

## Fluxo principal

A comunicacao em tempo real da aplicacao e feita com **WebSocket**.

1. O cliente cria sua conta.
2. O cliente se conecta e recebe os chats dos quais participa.
3. O cliente abre o chat desejado.
4. O cliente envia e recebe mensagens em tempo real.
5. O cliente recebe o historico inicial do chat.
6. O servidor envia novas mensagens no formato:
   `[conteudo, autor, hora, status]`

### Processamento das mensagens

1. O cliente acumula mensagens em buffer e envia para o servidor.
2. O servidor processa as mensagens e faz broadcast para os usuarios conectados.
3. O servidor atualiza o estado do chat (grupo ou privado).

## Tratamento de erros

- Se o usuario perder conexao, o servidor envia um aviso de reconexao.
- Mensagens nao entregues ficam em estado **pendente** ate confirmacao.
- Em caso de falha, o cliente recebe rollback das mensagens nao enviadas.
