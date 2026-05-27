import { useState } from 'react'
import { API_BASE } from '../lib/chat'

const tabs = [
  { key: 'login', label: 'Entrar' },
  { key: 'register', label: 'Cadastrar' },
]

export default function AuthScreen({ onAuth }) {
  const [tab, setTab] = useState('login')
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [pass, setPass] = useState('')
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const [loading, setLoading] = useState(false)

  const submit = async (event) => {
    event.preventDefault()

    if ((tab === 'register' && !name.trim()) || !email.trim() || !pass.trim()) {
      setError('Preencha todos os campos.')
      return
    }

    setLoading(true)
    setError('')
    setSuccess('')

    try {
      const url =
        tab === 'login'
          ? `${API_BASE}/api/auth/login`
          : `${API_BASE}/api/auth/register`

      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body:
          tab === 'login'
            ? JSON.stringify({ email, senha: pass })
            : JSON.stringify({ nome: name, email, senha: pass }),
      })

      const data = await response.json()

      if (!response.ok) {
        setError(data.detail || 'Erro desconhecido')
        return
      }

      if (tab === 'register') {
        setSuccess('Conta criada com sucesso. Faça login para continuar.')
        setTab('login')
        setName('')
        setPass('')
        return
      }

      onAuth({
        token: data.access_token,
        nome: data.nome || name,
        email,
        userId: data.user_id,
      })
    } catch {
      setError('Não foi possível conectar ao servidor.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="relative flex h-full w-full items-center justify-center overflow-hidden px-4">
      <div className="absolute -left-24 top-10 h-72 w-72 rounded-full bg-blue-500/20 blur-3xl" />
      <div className="absolute -right-20 bottom-0 h-72 w-72 rounded-full bg-cyan-400/10 blur-3xl" />

      <div className="relative w-full max-w-md rounded-[28px] border border-white/10 bg-slate-950/80 p-8 shadow-2xl shadow-black/40 backdrop-blur-xl sm:p-10">
        <div className="mb-2 text-3xl font-black tracking-tight text-white">
          Live<span className="text-blue-400">Chat</span>
        </div>
        <p className="mb-8 text-sm text-slate-400">Sistema de chat em tempo real</p>

        <div className="mb-7 grid grid-cols-2 gap-2 rounded-2xl bg-white/5 p-1">
          {tabs.map((item) => (
            <button
              key={item.key}
              type="button"
              onClick={() => setTab(item.key)}
              className={`rounded-xl px-4 py-2 text-sm font-semibold transition ${
                tab === item.key
                  ? 'bg-blue-500 text-white shadow-lg shadow-blue-500/20'
                  : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              {item.label}
            </button>
          ))}
        </div>

        <form onSubmit={submit} className="space-y-3">
          {error ? (
            <div className="rounded-xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">
              {error}
            </div>
          ) : null}

          {success ? (
            <div className="rounded-xl border border-emerald-500/20 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-200">
              {success}
            </div>
          ) : null}

          {tab === 'register' ? (
            <input
              className="w-full rounded-2xl border border-white/10 bg-slate-900 px-4 py-3 text-sm text-white outline-none transition placeholder:text-slate-500 focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20"
              placeholder="Nome"
              value={name}
              onChange={(event) => setName(event.target.value)}
            />
          ) : null}

          <input
            className="w-full rounded-2xl border border-white/10 bg-slate-900 px-4 py-3 text-sm text-white outline-none transition placeholder:text-slate-500 focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20"
            placeholder="Email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
          />

          <input
            className="w-full rounded-2xl border border-white/10 bg-slate-900 px-4 py-3 text-sm text-white outline-none transition placeholder:text-slate-500 focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20"
            placeholder="Senha"
            type="password"
            value={pass}
            onChange={(event) => setPass(event.target.value)}
          />

          <button
            type="submit"
            disabled={loading}
            className="flex w-full items-center justify-center rounded-2xl bg-blue-500 px-4 py-3 text-sm font-semibold text-white transition hover:bg-blue-400 disabled:cursor-not-allowed disabled:bg-slate-700"
          >
            {loading ? 'Aguarde...' : tab === 'login' ? 'Entrar' : 'Criar conta'}
          </button>
        </form>
      </div>
    </div>
  )
}