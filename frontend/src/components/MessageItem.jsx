import { formatDateLabel, formatTime, getHue, getInitials } from '../lib/chat'

export default function MessageItem({ message, previousMessage, currentUsername }) {
  const isMine = message.sender === currentUsername
  const sameSender = previousMessage?.sender === message.sender
  const showDivider = !previousMessage || new Date(message.time).toDateString() !== new Date(previousMessage.time).toDateString()

  return (
    <div>
      {showDivider ? (
        <div className="my-4 flex items-center gap-3">
          <div className="h-px flex-1 bg-white/10" />
          <span className="whitespace-nowrap text-[11px] text-slate-500">{formatDateLabel(message.time)}</span>
          <div className="h-px flex-1 bg-white/10" />
        </div>
      ) : null}

      <div className={`flex items-end gap-2 ${isMine ? 'justify-end' : 'justify-start'}`}>
        {!isMine ? (
          <div
            className={`mb-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-[10px] font-bold text-white ${sameSender ? 'invisible' : 'visible'}`}
            style={{ background: `hsl(${getHue(message.sender)}, 58%, 43%)` }}
          >
            {getInitials(message.sender)}
          </div>
        ) : null}

        <div className="max-w-[420px]">
          {!isMine && !sameSender ? <div className="mb-1 text-xs font-semibold text-blue-300">{message.sender}</div> : null}

          <div
            className={`rounded-3xl px-4 py-3 text-sm leading-6 shadow-lg ${
              isMine
                ? 'rounded-br-md bg-gradient-to-br from-blue-500 to-blue-600 text-white shadow-blue-500/20'
                : 'rounded-bl-md border border-white/5 bg-slate-900 text-slate-100 shadow-black/20'
            }`}
          >
            <div className="break-words">{message.text}</div>
            <div className={`mt-2 text-right text-[10px] ${isMine ? 'text-white/60' : 'text-slate-500'}`}>
              {formatTime(message.time)}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}