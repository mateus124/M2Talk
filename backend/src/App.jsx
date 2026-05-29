import { useState, useEffect } from "react";
import { useChat } from "./hooks/useChat";

export default function App() {
  const [token, setToken] = useState("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6ImRvZG9yZXNAZXhhbXBsZS5jb20iLCJub21lIjoiZG9kb3ppbmhvVGNoYW4iLCJleHAiOjE3ODAxNTAyMzR9.hxRGwGgpNldwSmgzVlaPtbh7m-9ExOgOJL_2d99kqek");
  const [grupoAtivo, setGrupoAtivo] = useState(null);
  const [texto, setTexto] = useState("");

  const {
    mensagens,
    grupos,
    criarGrupo,
    entrarGrupo,
    enviarGrupo,
    listarGrupos
  } = useChat(token);

  useEffect(() => {
    if (token) {
      listarGrupos();
    }
  }, [token]);

  const handleCriarGrupo = () => {
    const nome = prompt("Digite o nome do novo grupo:");
    if (nome) {
      criarGrupo(nome);
    }
  };

  const handleEnviarMensagem = () => {
    if (texto.trim() && grupoAtivo) {
      enviarGrupo(grupoAtivo, texto);
      setTexto("");
    }
  };

  return (
    <div style={{ display: "flex", width: "100vw", height: "100vh", backgroundColor: "#060b13", color: "#fff", fontFamily: "sans-serif" }}>
      <aside style={{ width: "300px", backgroundColor: "#0b1424", display: "flex", flexDirection: "column", borderRight: "1px solid #1e293b" }}>
        <div style={{ padding: "20px", display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid #1e293b" }}>
          <h2 style={{ margin: 0, fontSize: "1.2rem", fontWeight: "bold", letterSpacing: "wider" }}>M2TALK</h2>
        </div>

        <div style={{ padding: "15px", display: "flex", alignItems: "center", gap: "12px" }}>
          <div style={{ width: "45px", height: "45px", borderRadius: "50%", backgroundColor: "#1e3a8a", display: "flex", alignItems: "center", justifyContent: "center", fontWeight: "bold", fontSize: "1.1rem" }}>
            DO
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontWeight: "bold", fontSize: "0.95rem" }}>dodozinhoTchan</div>
            <div style={{ display: "flex", alignItems: "center", gap: "5px", fontSize: "0.8rem", color: "#10b981" }}>
              <span style={{ width: "8px", height: "8px", borderRadius: "50%", backgroundColor: "#10b981" }}></span>
              Online
            </div>
          </div>
        </div>

        <div style={{ padding: "0 15px 15px 15px" }}>
          <input
            type="text"
            placeholder="Buscar conversas..."
            style={{ width: "100%", padding: "10px", borderRadius: "8px", backgroundColor: "#0f1a2c", border: "1px solid #1e293b", color: "#fff", boxSizing: "border-box" }}
          />
        </div>

        <div style={{ flex: 1, overflowY: "auto", padding: "0 15px" }}>
          {grupos.map((grupo) => (
            <div
              key={grupo.id}
              onClick={() => {
                setGrupoAtivo(grupo.nome);
                entrarGrupo(grupo.nome);
              }}
              style={{
                display: "flex",
                alignItems: "center",
                gap: "12px",
                padding: "12px",
                borderRadius: "8px",
                cursor: "pointer",
                backgroundColor: grupoAtivo === grupo.nome ? "#1e293b" : "transparent",
                marginBottom: "8px"
              }}
            >
              <div style={{ width: "35px", height: "35px", borderRadius: "50%", backgroundColor: "#4f46e5", display: "flex", alignItems: "center", justifyContent: "center" }}>
                ✨
              </div>
              <div>
                <div style={{ fontWeight: "500", fontSize: "0.95rem" }}>{grupo.nome}</div>
                <div style={{ fontSize: "0.8rem", color: "#94a3b8" }}>Grupo</div>
              </div>
            </div>
          ))}
        </div>

        <div style={{ padding: "15px" }}>
          <button
            onClick={handleCriarGrupo}
            style={{ width: "100%", padding: "12px", borderRadius: "8px", backgroundColor: "#0f1a2c", border: "1px solid #1e293b", color: "#fff", fontWeight: "bold", cursor: "pointer" }}
          >
            + Novo Grupo
          </button>
        </div>
      </aside>

      <main style={{ flex: 1, display: "flex", flexDirection: "column", backgroundColor: "#060b13" }}>
  {!grupoAtivo ? (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", color: "#64748b" }}>
      <div style={{ fontSize: "3rem", marginBottom: "10px" }}>💬</div>
      <p style={{ margin: 0, fontSize: "1rem" }}>Selecione uma conversa ou crie um grupo</p>
    </div>
  ) : (
    <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
      <div style={{ padding: "20px", borderBottom: "1px solid #1e293b", backgroundColor: "#0b1424" }}>
        <h3 style={{ margin: 0, fontSize: "1.1rem" }}>#{grupoAtivo}</h3>
      </div>

      <div style={{ flex: 1, padding: "20px", overflowY: "auto", display: "flex", flexDirection: "column", gap: "12px" }}>
        {mensagens
          .filter((msg) => msg.group_name === grupoAtivo || msg.type === "system" || msg.type === "group_created" || !msg.group_name || msg.message_type === "group")
          .map((msg, index) => (
            <div
              key={index}
              style={{
                alignSelf: msg.type === "system" || msg.type === "group_created" ? "center" : "flex-start",
                backgroundColor: msg.type === "system" || msg.type === "group_created" ? "#1e293b" : "#0f1a2c",
                padding: "10px 14px",
                borderRadius: "8px",
                maxWidth: "70%",
                fontSize: "0.95rem"
              }}
            >
              {msg.type !== "system" && msg.type !== "group_created" && (
                <div style={{ fontWeight: "bold", fontSize: "0.8rem", color: "#818cf8", marginBottom: "4px" }}>
                  {msg.nome || msg.autor || "Usuário"}
                </div>
              )}
              <span style={{ color: msg.type === "system" || msg.type === "group_created" ? "#94a3b8" : "#fff" }}>
                {msg.content || msg.message || msg.conteudo || JSON.stringify(msg)}
              </span>
            </div>
          ))}
      </div>

      <div style={{ padding: "20px", backgroundColor: "#0b1424", display: "flex", gap: "12px" }}>
        <input
          type="text"
          placeholder={`Conversar em #${grupoAtivo}`}
          value={texto}
          onChange={(e) => setTexto(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") handleEnviarMensagem();
          }}
          style={{ flex: 1, padding: "12px", borderRadius: "8px", backgroundColor: "#060b13", border: "1px solid #1e293b", color: "#fff" }}
        />
        <button
          onClick={handleEnviarMensagem}
          style={{ padding: "0 20px", borderRadius: "8px", backgroundColor: "#4f46e5", border: "none", color: "#fff", fontWeight: "bold", cursor: "pointer" }}
        >
          Enviar
        </button>
      </div>
    </div>
  )}
</main>
    </div>
  );
}