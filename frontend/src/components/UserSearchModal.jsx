import { useState } from 'react'
import { FiX, FiMessageSquare, FiUserPlus } from 'react-icons/fi'
import { API_BASE } from '../lib/chat'

export default function UserSearchModal({
  auth,
  sendWsAction,
  groupName,
  onClose,
  onOpenConversation,
  onAddToGroup,
}) {
  const [username, setUsername] = useState('')
  const [results, setResults] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const [adding, setAdding] = useState(null)

  const searchUsers = async (event) => {
    event.preventDefault()
    if (!username.trim()) {
      setError('Digite um username para buscar.')
      return
    }

    setLoading(true)
    setError('')
    setSuccess('')

    try {
      const response = await fetch(
        `${API_BASE}/api/users/search?username=${encodeURIComponent(username)}`,
        {
          headers: {
            Authorization: `Bearer ${auth?.token}`,
          },
        },
      )

      const data = await response.json()
      if (!response.ok) {
        setError(data.detail || 'Erro ao buscar usuários.')
        setResults([])
        return
      }

      setResults(data)
    } catch {
      setError('Não foi possível buscar usuários no servidor.')
      setResults([])
    } finally {
      setLoading(false)
    }
  }

  const handleAddUser = async (user) => {
    if (!groupName) {
      setError('Selecione um grupo para adicionar o usuário.')
      return
    }

    setAdding(user.id)
    setError('')
    setSuccess('')

    try {
      if (typeof sendWsAction === 'function') {
        sendWsAction({ action: 'invite_user', group_name: groupName, username: user.nome })
        setSuccess('Convite enviado pelo WebSocket.')
        if (typeof onAddToGroup === 'function') {
          onAddToGroup(user)
        }
        return
      }

      const response = await fetch(`${API_BASE}/api/groups/${groupName}/members`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${auth?.token}`,
        },
        body: JSON.stringify({ username: user.nome }),
      })

      const data = await response.json()
      if (!response.ok) {
        setError(data.detail || 'Erro ao adicionar usuário ao grupo.')
        return
      }

      setSuccess(data.detail || 'Usuário adicionado ao grupo com sucesso')
      if (typeof onAddToGroup === 'function') {
        onAddToGroup(user)
      }
    } catch {
      setError('Não foi possível adicionar o usuário ao grupo.')
    } finally {
      setAdding(null)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/70 p-4">
      <div className="w-full max-w-2xl rounded-[32px] border border-white/10 bg-slate-950 p-6 shadow-2xl shadow-black/40">
        <div className="mb-4 flex items-center justify-between">
          <div>
            <p className="text-lg font-semibold text-white">Buscar usuário</p>
            <p className="mt-1 text-sm text-slate-400">
              Pesquise por username para abrir uma mensagem privada ou adicionar ao grupo selecionado.
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="rounded-full p-2 text-slate-300 transition hover:bg-white/5 hover:text-white"
          >
            <FiX className="text-lg" />
          </button>
        </div>

        <form onSubmit={searchUsers} className="mb-4 flex gap-2">
          <input
            className="flex-1 rounded-2xl border border-white/10 bg-slate-900 px-4 py-3 text-sm text-white outline-none transition placeholder:text-slate-500 focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20"
            placeholder="Digite o username"
            value={username}
            onChange={(event) => setUsername(event.target.value)}
          />
          <button
            type="submit"
            disabled={loading}
            className="rounded-2xl bg-blue-500 px-5 py-3 text-sm font-semibold text-white transition hover:bg-blue-400 disabled:cursor-not-allowed disabled:bg-slate-700"
          >
            {loading ? 'Buscando...' : 'Buscar'}
          </button>
        </form>

        {error ? (
          <div className="mb-4 rounded-2xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">
            {error}
          </div>
        ) : null}

        {success ? (
          <div className="mb-4 rounded-2xl border border-emerald-500/20 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-200">
            {success}
          </div>
        ) : null}

        <div className="rounded-3xl border border-white/10 bg-slate-900 p-4">
          {results.length === 0 ? (
            <div className="text-sm text-slate-500">Nenhum usuário encontrado.</div>
          ) : (
            <div className="space-y-3">
              {results.map((user) => (
                <div key={user.id} className="flex flex-col gap-2 rounded-3xl border border-white/5 bg-slate-950/80 p-4 sm:flex-row sm:items-center sm:justify-between">
                  <div className="min-w-0">
                    <div className="truncate text-sm font-semibold text-white">{user.nome}</div>
                    <div className="mt-1 text-xs text-slate-400">ID: {user.id}</div>
                  </div>

                  <div className="flex flex-wrap gap-2">
                    <button
                      type="button"
                      onClick={() => onOpenConversation(user)}
                      className="inline-flex items-center gap-2 rounded-2xl bg-slate-800 px-4 py-2 text-sm font-semibold text-slate-100 transition hover:bg-slate-700"
                    >
                      <FiMessageSquare />
                      Mensagem privada
                    </button>
                    <button
                      type="button"
                      onClick={() => handleAddUser(user)}
                      disabled={!groupName || adding === user.id}
                      className="inline-flex items-center gap-2 rounded-2xl bg-blue-500 px-4 py-2 text-sm font-semibold text-white transition hover:bg-blue-400 disabled:cursor-not-allowed disabled:bg-slate-700"
                    >
                      <FiUserPlus />
                      {adding === user.id ? 'Adicionando...' : 'Adicionar ao grupo'}
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <p className="mt-4 text-xs text-slate-500">
          {groupName
            ? `Usuário será adicionado ao grupo ${groupName}.`
            : 'Selecione um grupo para habilitar a adição de usuários.'}
        </p>
      </div>
    </div>
  )
}
