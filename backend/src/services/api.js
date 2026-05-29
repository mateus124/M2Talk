import { API_BASE_URL } from '../config';

export async function fazerLogin(email, password) {
  const response = await fetch(`${API_BASE_URL}/auth/login`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ email, password })
  });

  if (!response.ok) {
    throw new Error("Erro no login");
  }

  return await response.json();
}

export async function buscarHistorico(token) {
  const response = await fetch(`${API_BASE_URL}/chat/history`, {
    headers: {
      "Authorization": `Bearer ${token}`
    }
  });

  if (!response.ok) {
    throw new Error("Erro ao buscar histórico");
  }

  return await response.json();
}