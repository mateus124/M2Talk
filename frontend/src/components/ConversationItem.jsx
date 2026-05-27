import { HiSparkles } from 'react-icons/hi2'

import { formatTime, getHue, getInitials } from '../lib/chat'

export default function ConversationItem({ conversation, active, lastMessage, onClick }) {
  const isGroup = conversation.type === 'group'
  const title = conversation.nome || conversation.name

  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex w-full items-center gap-3 rounded-2xl border px-3 py-3 text-left transition ${
        active
          ? 'border-blue-400/25 bg-blue-500/10 shadow-lg shadow-blue-500/5'
          : 'border-transparent hover:border-white/10 hover:bg-white/5'
      }`}
    >
      <div
        className={`flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden text-xs font-bold text-white ${
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
        {isGroup ? <HiSparkles className="text-base text-white" /> : getInitials(conversation.name)}
      </div>

      <div className="min-w-0 flex-1">
        <div className="truncate text-sm font-semibold text-slate-100">{title}</div>
        <div className="mt-1 truncate text-xs text-slate-400">
          {lastMessage ? `${lastMessage.sender}: ${lastMessage.text}` : isGroup ? 'Grupo' : 'DM'}
        </div>
      </div>

      {lastMessage ? <div className="shrink-0 text-[10px] text-slate-500">{formatTime(lastMessage.time)}</div> : null}
    </button>
  )
}