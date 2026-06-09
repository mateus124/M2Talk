# M2Talk

Projeto da disciplina de Sistemas Distribuidos.

- Numero da lista: 29
- Integrantes: Mateus Alves e Mateus Dodó

## Sobre a aplicacao

O M2Talk e uma aplicacao de chat em tempo real com suporte a:

- Conversas privadas
- Conversas em grupo
- Sincronizacao de mensagens via WebSocket

## Arquitetura do projeto

A aplicação é composta por três principais camadas:

- Backend: Desenvolvido em Python com FastAPI, responsável pela autenticação, gerenciamento de usuários, persistência de dados e comunicação em tempo real via WebSocket.

- Frontend: Construído em React + Vite, fornece a interface web para interação com o sistema.

- App Mobile: Desenvolvido em Flutter, oferece uma experiência nativa para dispositivos móveis, integrando-se ao backend via API e WebSocket.

Essa arquitetura garante escalabilidade, modularidade e suporte multiplataforma.

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

Configuração com .env.example: 

O backend utiliza variáveis de ambiente para configurar banco de dados, chaves secretas e parâmetros de rede.
Antes de rodar o servidor, copie o arquivo .env.example e ajuste conforme necessário:

```bash
cp .env.example .env
```
Edite o arquivo .env com suas credenciais e configurações locais.

Instale as dependencias e inicie o servidor:

```bash
uv sync
fastapi dev src/main.py --host 0.0.0.0 --port 8000
```

- App Mobile (Flutter):

```bash
cd flutter_application
flutter pub get
flutter run
```
O app mobile se conecta ao mesmo backend e permite que os usuários utilizem o chat em tempo real diretamente em seus dispositivos.

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


