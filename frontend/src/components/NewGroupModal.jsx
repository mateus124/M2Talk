import { useState } from 'react'

export default function NewGroupModal({ token, onClose, onCreated, onSendWsAction }) {
  const [name, setName] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const createGroup = async (event) => {
    event.preventDefault()

    if (!name.trim()) {
      setError('Informe um nome.')
      return
    }

    setLoading(true)
    setError('')

    try {
      if (typeof onSendWsAction === 'function') {
        onSendWsAction({ action: 'create_group', group_name: name })
        onCreated(name)
        return
      }

      const response = await fetch(`/api/groups`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ nome: name }),
      })

      const data = await response.json()

      if (!response.ok) {
        setError(data.detail || 'Erro')
        return
      }

      onCreated(name)
    } catch {
      setError('Erro de conexão.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 px-4 backdrop-blur-sm" onClick={onClose}>
      <div
        className="w-full max-w-sm rounded-3xl border border-white/10 bg-slate-950 p-6 shadow-2xl shadow-black/50"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="mb-5 text-lg font-bold text-white">Novo Grupo</div>

        <form onSubmit={createGroup} className="space-y-3">
          {error ? (
            <div className="rounded-xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">
              {error}
            </div>
          ) : null}

          <input
            className="w-full rounded-2xl border border-white/10 bg-slate-900 px-4 py-3 text-sm text-white outline-none transition placeholder:text-slate-500 focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20"
            placeholder="Nome do grupo"
            value={name}
            onChange={(event) => setName(event.target.value)}
          />

          <div className="grid grid-cols-2 gap-3">
            <button
              type="button"
              onClick={onClose}
              className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm font-semibold text-slate-300 transition hover:bg-white/10"
            >
              Cancelar
            </button>

            <button
              type="submit"
              disabled={loading}
              className="rounded-2xl bg-blue-500 px-4 py-3 text-sm font-semibold text-white transition hover:bg-blue-400 disabled:cursor-not-allowed disabled:bg-slate-700"
            >
              {loading ? 'Criando...' : 'Criar'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}