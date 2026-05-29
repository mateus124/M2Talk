import { useState, useEffect, useRef } from "react";
import { WS_BASE_URL } from "../config";

export function useChat(token) {
  const [mensagens, setMensagens] = useState([]);
  const [grupos, setGrupos] = useState([]);
  const ws = useRef(null);

  useEffect(() => {
    if (!token) return;

    ws.current = new WebSocket(`${WS_BASE_URL}?token=${token}`);

    ws.current.onmessage = (event) => {
      const data = JSON.parse(event.data);
      
      if (data.type === "groups") {
        setGrupos(data.groups);
      } else if (data.type === "group_created") {
        setMensagens((prev) => [...prev, data]);
        if (ws.current && ws.current.readyState === WebSocket.OPEN) {
          ws.current.send(JSON.stringify({ action: "list_groups" }));
        }
      } else {
        setMensagens((prev) => [...prev, data]);
      }
    };

    return () => {
      if (ws.current) {
        ws.current.close();
      }
    };
  }, [token]);

  const emitir = (payload) => {
    if (ws.current && ws.current.readyState === WebSocket.OPEN) {
      ws.current.send(JSON.stringify(payload));
    }
  };

  const enviarBroadcast = (message) => {
    emitir({ action: "broadcast", message });
  };

  const enviarPrivado = (recipientId, message) => {
    emitir({ action: "private_message", recipient_id: recipientId, message });
  };

  const criarGrupo = (groupName) => {
    emitir({ action: "create_group", group_name: groupName });
  };

  const entrarGrupo = (groupName) => {
    emitir({ action: "join_group", group_name: groupName });
  };

  const sairGrupo = (groupName) => {
    emitir({ action: "leave_group", group_name: groupName });
  };

  const enviarGrupo = (groupName, message) => {
    emitir({ action: "group_message", group_name: groupName, message });
  };

  const listarGrupos = () => {
    emitir({ action: "list_groups" });
  };

  const consultarMembrosGrupo = (groupName) => {
    emitir({ action: "group_member_count", group_name: groupName });
  };

  return {
    mensagens,
    grupos,
    enviarBroadcast,
    enviarPrivado,
    criarGrupo,
    entrarGrupo,
    sairGrupo,
    enviarGrupo,
    listarGrupos,
    consultarMembrosGrupo
  };
}