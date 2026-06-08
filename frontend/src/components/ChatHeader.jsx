import { HiSparkles } from 'react-icons/hi2'
import { FiLogOut, FiTrash2 } from 'react-icons/fi'

import { getHue, getInitials } from '../lib/chat'

export default function ChatHeader({ active, wsStatus, onLeaveGroup, onDeleteGroup, canDeleteGroup }) {
  const isGroup = active.type === 'group'
  const title = active.nome || active.name

  return (
    <div className="flex items-center gap-4 border-b border-white/10 bg-slate-950/80 px-5 py-4 backdrop-blur-xl">
      <div
        className={`flex h-11 w-11 shrink-0 items-center justify-center overflow-hidden text-sm font-bold text-white ${
          isGroup ? 'rounded-2xl' : 'rounded-full'
        }`}
        style={
          isGroup
            ? {
                background: `linear-gradient(135deg, hsl(${getHue(title)}, 58%, 43%), hsl(${getHue(title) + 35}, 58%, 34%))`,
              }
            : { background: `hsl(${getHue(title)}, 58%, 43%)` }
        }
      >
        {isGroup ? <HiSparkles className="text-lg text-white" /> : getInitials(title)}
      </div>

      <div>
        <div className="text-sm font-bold text-white">{title}</div>
        <div className="mt-1 text-xs text-slate-400">{isGroup ? 'Grupo' : 'Mensagem direta'}</div>
      </div>

      <div className="ml-auto flex items-center gap-2">
        {isGroup ? (
          <>
            <button
              type="button"
              onClick={onLeaveGroup}
              className="inline-flex items-center gap-2 rounded-2xl border border-white/10 bg-slate-900 px-3 py-2 text-xs font-semibold text-slate-200 transition hover:bg-slate-800"
            >
              <FiLogOut className="text-sm" />
              Sair
            </button>
            {canDeleteGroup ? (
              <button
                type="button"
                onClick={onDeleteGroup}
                className="inline-flex items-center gap-2 rounded-2xl border border-red-500/20 bg-red-500/10 px-3 py-2 text-xs font-semibold text-red-200 transition hover:bg-red-500/20"
              >
                <FiTrash2 className="text-sm" />
                Excluir
              </button>
            ) : null}
          </>
        ) : null}
        <div
          className={`flex items-center gap-2 rounded-full px-3 py-1 text-xs font-medium ${
            wsStatus ? 'bg-emerald-500/10 text-emerald-400' : 'bg-red-500/10 text-red-300'
          }`}
        >
          <span className={`h-2 w-2 rounded-full ${wsStatus ? 'bg-emerald-400' : 'bg-red-400'}`} />
          {wsStatus ? 'Conectado' : 'Reconectando...'}
        </div>
      </div>
    </div>
  )
}