import { HiOutlineChatBubbleOvalLeftEllipsis } from 'react-icons/hi2'

import MessageItem from './MessageItem'

export default function MessageList({ messages, currentUsername, listRef }) {
  return (
    <div ref={listRef} className="flex-1 overflow-y-auto px-6 py-5">
      {messages.length === 0 ? (
        <div className="mt-10 flex flex-col items-center gap-2 text-center text-sm text-slate-500">
          <HiOutlineChatBubbleOvalLeftEllipsis className="text-2xl opacity-60" />
          <span>Nenhuma mensagem ainda. Diga olá!</span>
        </div>
      ) : null}

      <div className="space-y-1">
        {messages.map((message, index) => (
          <MessageItem
            key={`${message.time}-${index}`}
            message={message}
            previousMessage={messages[index - 1]}
            currentUsername={currentUsername}
          />
        ))}
      </div>
    </div>
  )
}