export const WS_BASE = 'ws://127.0.0.1:8000'
export const API_BASE = 'http://127.0.0.1:8000'

export const formatTime = (iso) => {
  const date = new Date(iso)
  return date.toLocaleTimeString('pt-BR', {
    hour: '2-digit',
    minute: '2-digit',
  })
}

export const formatDateLabel = (iso) =>
  new Date(iso).toLocaleDateString('pt-BR', {
    day: '2-digit',
    month: 'short',
  })

export const getInitials = (name = '') => resolveDisplayName(name, '').slice(0, 2).toUpperCase() || '??'

export const normalizeGroup = (group) => {
  if (!group) return null

  if (typeof group === 'string') {
    return { id: group, name: group, nome: group }
  }

  return {
    ...group,
    id: group.id ?? group.nome ?? group.name,
    name: group.nome ?? group.name,
    nome: group.nome ?? group.name,
  }
}

const resolveDisplayName = (value, fallback = 'servidor') => {
  if (typeof value === 'string') return value
  if (typeof value === 'number' || typeof value === 'boolean') return String(value)

  if (value && typeof value === 'object') {
    return value.nome || value.name || value.email || value.username || value.label || fallback
  }

  return fallback
}

export const normalizeMessage = (message, fallbackKey = 'server') => {
  const senderObject =
    (message.from && typeof message.from === 'object' && message.from) ||
    (message.from_ && typeof message.from_ === 'object' && message.from_) ||
    null
  const senderName = resolveDisplayName(
    message.from_name || message.sender_name || senderObject || message.from || message.from_ || message.sender,
  )
  const senderId = message.from_id ?? message.sender_id ?? senderObject?.user_id ?? senderObject?.id ?? null
  const recipientId = message.recipient_id ?? message.to_id ?? null
  const conversationKey = (
    message.conversation_key ||
    message.group_name ||
    message.group ||
    message.chat_key ||
    message.thread_key ||
    senderId ||
    senderName ||
    fallbackKey
  );
  const conversationName = message.conversation_name || message.group_name || message.group || senderName

  return {
    ...message,
    sender: senderName,
    senderId,
    recipientId,
    text: message.message || message.content || message.text || JSON.stringify(message),
    time: message.timestamp || message.created_at || new Date().toISOString(),
    conversationKey,
    conversationName,
  }
}

export const getHue = (name = '') => {
  const normalizedName = resolveDisplayName(name, '')
  let hue = 0

  for (const char of normalizedName) {
    hue = (hue * 31 + char.charCodeAt(0)) % 360
  }

  return hue
}