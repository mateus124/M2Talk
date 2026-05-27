import { HiChatBubbleLeftRight } from 'react-icons/hi2'

export default function EmptyState() {
  return (
    <div className="flex h-full flex-col items-center justify-center gap-3 px-6 text-center text-slate-500">
      <HiChatBubbleLeftRight className="text-5xl opacity-30" />
      <div className="text-sm">Selecione uma conversa ou crie um grupo</div>
    </div>
  )
}