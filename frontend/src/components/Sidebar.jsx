import { FiLogOut, FiSearch, FiPlus } from 'react-icons/fi'

import ConversationItem from './ConversationItem'
import { getHue, getInitials } from '../lib/chat'

export default function Sidebar({
  auth,
  conversations,
  activeName,
  search,
  onSearchChange,
  onSelectConversation,
  onCreateGroup,
  onSearchUsers,
  onLogout,
}) {
  return (
    <aside className="flex h-full w-[290px] min-w-[290px] flex-col border-r border-white/10 bg-slate-950/80 backdrop-blur-xl">
      <div className="border-b border-white/10 p-4">
        <div className="mb-4 flex items-center gap-3">
          <div
            className="flex h-11 w-11 items-center justify-center rounded-full text-sm font-bold text-white"
            style={{ background: `hsl(${getHue(auth.nome)}, 58%, 43%)` }}
          >
            {getInitials(auth.nome)}
          </div>

          <div className="min-w-0 flex-1">
            <div className="truncate text-sm font-semibold text-white">{auth.nome}</div>
            <div className="mt-1 flex items-center gap-2 text-xs text-emerald-400">
              <span className="h-2 w-2 rounded-full bg-emerald-400" />
              Online
            </div>
          </div>

          <button
            type="button"
            title="Sair"
            onClick={onLogout}
            className="rounded-lg p-2 text-slate-400 transition hover:bg-white/5 hover:text-white"
          >
            <FiLogOut className="text-lg" />
          </button>
        </div>

        <input
          className="w-full rounded-2xl border border-white/10 bg-slate-900 px-4 py-3 text-sm text-white outline-none transition placeholder:text-slate-500 focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20"
          placeholder="Buscar conversas..."
          value={search}
          onChange={(event) => onSearchChange(event.target.value)}
        />
      </div>

      <div className="flex-1 space-y-2 overflow-y-auto p-3">
        {conversations.length === 0 ? (
          <div className="px-2 py-10 text-center text-sm text-slate-500">Nenhuma conversa ainda</div>
        ) : (
          conversations.map((conversation) => (
            <ConversationItem
              key={conversation.name}
              conversation={conversation}
              active={activeName === conversation.name}
              lastMessage={conversation.lastMessage}
              onClick={() => onSelectConversation(conversation)}
            />
          ))
        )}
      </div>

      <div className="border-t border-white/10 p-3 space-y-3">
        <button
          type="button"
          onClick={onCreateGroup}
          className="flex w-full items-center justify-center gap-2 rounded-2xl border border-dashed border-blue-400/30 bg-blue-500/10 px-4 py-3 text-sm font-semibold text-blue-300 transition hover:bg-blue-500/15"
        >
          <FiPlus className="text-base" />
          Novo Grupo
        </button>
        <button
          type="button"
          onClick={onSearchUsers}
          className="flex w-full items-center justify-center gap-2 rounded-2xl border border-white/10 bg-slate-900 px-4 py-3 text-sm font-semibold text-slate-100 transition hover:bg-slate-800"
        >
          <FiSearch className="text-base" />
          Buscar usuário
        </button>
      </div>
    </aside>
  )
}