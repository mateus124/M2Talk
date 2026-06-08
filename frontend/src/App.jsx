import { useCallback, useEffect, useRef, useState } from 'react'
import AuthScreen from './components/AuthScreen'
import ChatHeader from './components/ChatHeader'
import EmptyState from './components/EmptyState'
import MessageInput from './components/MessageInput'
import MessageList from './components/MessageList'
import NewGroupModal from './components/NewGroupModal'
import Sidebar from './components/Sidebar'
import UserSearchModal from './components/UserSearchModal'
import { API_BASE, WS_BASE, normalizeGroup, normalizeMessage } from './lib/chat'

const AUTH_STORAGE_KEY = 'm2talk-auth'

const readStoredAuth = () => {
  if (typeof window === 'undefined') return null

  try {
    const raw = window.localStorage.getItem(AUTH_STORAGE_KEY)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

export default function App() {
  const [auth, setAuth] = useState(() => readStoredAuth())
  const [groups, setGroups] = useState([])
  const [active, setActive] = useState(null)
  const [messages, setMessages] = useState({})
  const [input, setInput] = useState('')
  const [wsStatus, setWsStatus] = useState(false)
  const [showNewGroup, setShowNewGroup] = useState(false)
  const [showUserSearch, setShowUserSearch] = useState(false)
  const [search, setSearch] = useState('')

  const wsRef = useRef(null)
  const reconnectRef = useRef(null)
  const reconnectEnabledRef = useRef(false)
  const connectWSRef = useRef(null)
  const messageListRef = useRef(null)
  const clearReconnectTimer = useCallback(() => {
    if (reconnectRef.current) {
      window.clearTimeout(reconnectRef.current)
      reconnectRef.current = null
    }
  }, [])

  const closeSocket = useCallback(() => {
    const socket = wsRef.current

    if (!socket) return

    socket.onopen = null
    socket.onclose = null
    socket.onerror = null
    socket.onmessage = null
    socket.close()
    wsRef.current = null
  }, [])

  const connectWS = useCallback(
    (authData) => {
      const wsName = authData?.nome || authData?.username || authData?.email

      if (!authData?.token || !wsName) return

      reconnectEnabledRef.current = true
      clearReconnectTimer()

      if (wsRef.current) {
        closeSocket()
      }

      const socket = new WebSocket(`${WS_BASE}/ws?token=${authData.token}`)

      socket.onopen = () => setWsStatus(true)
      socket.onerror = () => setWsStatus(false)
      socket.onclose = () => {
        setWsStatus(false)

        if (!reconnectEnabledRef.current) return

        clearReconnectTimer()
        reconnectRef.current = window.setTimeout(() => connectWSRef.current?.(authData), 3000)
      }
      socket.onmessage = (event) => {
        try {
          const payload = JSON.parse(event.data)

          if (payload.type === 'groups' && Array.isArray(payload.groups)) {
            setGroups(payload.groups.map(normalizeGroup).filter(Boolean))
            return
          }

          if (payload.type === 'group_created' && payload.group_name) {
            setGroups((current) => {
              const exists = current.some((group) => group.name === payload.group_name)
              if (exists) return current
              return [...current, normalizeGroup({ id: payload.group_name, nome: payload.group_name, name: payload.group_name })]
            })
            void selectConversation({ type: 'group', name: payload.group_name })
            return
          }

          if (payload.type === 'group_joined' && payload.group_name) {
            setGroups((current) => {
              const exists = current.some((group) => group.name === payload.group_name)
              if (exists) return current
              return [...current, normalizeGroup({ id: payload.group_name, nome: payload.group_name, name: payload.group_name })]
            })
            return
          }

          if (payload.type === 'group_deleted' && payload.group_name) {
            setGroups((current) => current.filter((group) => group.name !== payload.group_name))
            setMessages((prev) => {
              const next = { ...prev }
              delete next[payload.group_name]
              return next
            })
            if (active?.name === payload.group_name) {
              setActive(null)
            }
            return
          }

          if (payload.type === 'group_left' && payload.group_name) {
            setGroups((current) => current.filter((group) => group.name !== payload.group_name))
            setMessages((prev) => {
              const next = { ...prev }
              delete next[payload.group_name]
              return next
            })
            if (active?.name === payload.group_name) {
              setActive(null)
            }
            return
          }

          if (payload.type === 'system') {
            console.info('Sistema:', payload.message)
            return
          }

          if (payload.type === 'group' || payload.type === 'private' || payload.type === 'broadcast' || !payload.type) {
            const message = normalizeMessage(payload)
            const key = message.conversationKey

            setMessages((previous) => ({
              ...previous,
              [key]: [
                ...(previous[key] || []),
                message,
              ],
            }))
          }
        } catch (error) {
          console.error("Erro ao processar mensagem WebSocket:", error);
        }
      }

      wsRef.current = socket
    },
    [clearReconnectTimer, closeSocket],
  )

  const sendWsAction = useCallback((payload) => {
    const socket = wsRef.current
    if (!socket || socket.readyState !== WebSocket.OPEN) {
      throw new Error('WebSocket não está conectado')
    }

    socket.send(JSON.stringify(payload))
  }, [])

  const fetchGroups = useCallback(async (token) => {
    if (!token) return

    try {
      const response = await fetch(`${API_BASE}/api/groups`, {
        headers: { Authorization: `Bearer ${token}` },
      })

      const data = await response.json()
      const list = Array.isArray(data) ? data : Array.isArray(data?.groups) ? data.groups : []
      setGroups(list.map(normalizeGroup).filter(Boolean))
    } catch {
      setGroups([])
    }
  }, [])

  const fetchHistory = useCallback(async (token) => {
    if (!token) return {}

    try {
      const response = await fetch(`${API_BASE}/api/chat/history`, {
        headers: { Authorization: `Bearer ${token}` },
      })

      const data = await response.json()
      const history = Array.isArray(data) ? data : []

      return history.reduce((accumulator, item) => {
        const message = normalizeMessage(item)
        const key = message.conversationKey

        if (!accumulator[key]) {
          accumulator[key] = []
        }

        accumulator[key].push(message)
        return accumulator
      }, {})
    } catch {
      return {}
    }
  }, [])

  useEffect(() => {
    if (!messageListRef.current) return

    messageListRef.current.scrollTop = messageListRef.current.scrollHeight
  }, [active?.name, messages, active])

  useEffect(() => {
    return () => {
      reconnectEnabledRef.current = false
      clearReconnectTimer()
      closeSocket()
    }
  }, [clearReconnectTimer, closeSocket])

  useEffect(() => {
    if (!auth?.token) {
      if (typeof window !== 'undefined') {
        window.localStorage.removeItem(AUTH_STORAGE_KEY)
      }

      reconnectEnabledRef.current = false
      clearReconnectTimer()
      closeSocket()
      setWsStatus(false)
      setGroups([])
      setMessages({})
      setActive(null)
      return
    }

    if (typeof window !== 'undefined') {
      window.localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(auth))
    }

    setActive(null)
    void fetchHistory(auth.token).then(setMessages)
    connectWS(auth)
    void fetchGroups(auth.token)
  }, [auth, clearReconnectTimer, closeSocket, connectWS, fetchGroups, fetchHistory])

  const handleAuth = useCallback(
    (authData) => {
      setAuth(authData)
      setInput('')
      setSearch('')
      setShowNewGroup(false)
      setShowUserSearch(false)
    },
    [],
  )

  useEffect(() => {
    connectWSRef.current = connectWS
  }, [connectWS])

  const handleLogout = useCallback(() => {
    reconnectEnabledRef.current = false
    clearReconnectTimer()
    closeSocket()
    setWsStatus(false)
    setAuth(null)
    setGroups([])
    setActive(null)
    setMessages({})
    setInput('')
    setSearch('')
    setShowNewGroup(false)
    setShowUserSearch(false)
  }, [clearReconnectTimer, closeSocket])

  const selectConversation = useCallback(
    (conversation) => {
      setActive(conversation)
    },
    [],
  )

  const handleOpenDirectMessage = useCallback(
    (user) => {
      if (!auth?.userId || !user?.id) return

      const me = Number(auth.userId)
      const target = Number(user.id)
      const name = `private:${Math.min(me, target)}:${Math.max(me, target)}`

      setActive({
        type: 'dm',
        name,
        nome: user.nome,
        recipientId: target,
      })
      setShowUserSearch(false)
    },
    [auth?.userId],
  )

  const handleAddUserToGroup = useCallback(
    async (user) => {
      if (!auth?.token || !active?.type || active.type !== 'group') return

      try {
        sendWsAction({ action: 'invite_user', group_name: active.name, username: user.nome })
      } catch {
        // ignore; modal will handle server responses
      }
    },
    [active, auth?.token, sendWsAction],
  )

  const handleLeaveGroup = useCallback(() => {
    if (!active?.type || active.type !== 'group' || !auth?.token) return

    try {
      sendWsAction({ action: 'leave_group', group_name: active.name })
      setActive(null)
    } catch {
      // ignore
    }
  }, [active, auth?.token, sendWsAction])

  const handleDeleteGroup = useCallback(() => {
    if (!active?.type || active.type !== 'group' || !auth?.token) return

    try {
      sendWsAction({ action: 'delete_group', group_name: active.name })
      setActive(null)
    } catch {
      // ignore
    }
  }, [active, auth?.token, sendWsAction])

  const sendMessage = useCallback(() => {
    const text = input.trim()

    if (!text || !active || !auth) return

    setInput('')

    try {
      if (active.type === 'group') {
        sendWsAction({ action: 'group_message', group_name: active.name, message: text })
        return
      }

      if (!active.recipientId) {
        return
      }

      sendWsAction({ action: 'private_message', recipient_id: active.recipientId, message: text })
    } catch { }
  }, [active, auth, input, sendWsAction])

  const handleGroupCreated = useCallback(
    async (name) => {
      setShowNewGroup(false)
      await fetchGroups(auth?.token)
      await selectConversation({ type: 'group', name })
    },
    [auth?.token, fetchGroups, selectConversation],
  )

  const groupNames = groups
    .map((group) => group?.nome || group?.name)
    .filter(Boolean)

  const authName = auth?.nome || auth?.username || auth?.email
  const conversations = [
    ...groups.map((group) => ({
      type: 'group',
      id: group.id,
      name: group.name,
      nome: group.nome,
      lastMessage: messages[group.name]?.at(-1),
    })),
    ...Object.keys(messages)
      .filter((name) => !groupNames.includes(name))
      .map((name) => {
        const lastMessage = messages[name]?.at(-1)
        const isMine = lastMessage?.sender === authName
        const displayName = lastMessage?.conversationName || lastMessage?.sender || name
        const recipientId = isMine ? lastMessage?.recipientId : lastMessage?.senderId

        return {
          type: 'dm',
          name,
          nome: displayName,
          recipientId,
          lastMessage,
        }
      }),
  ].filter((conversation) => (conversation.nome || conversation.name).toLowerCase().includes(search.toLowerCase()))
  .sort((left, right) => {
    const leftTime = left.lastMessage?.time ?? ''
    const rightTime = right.lastMessage?.time ?? ''

    if (!leftTime && !rightTime) return 0
    if (!leftTime) return 1
    if (!rightTime) return -1
    return rightTime.localeCompare(leftTime)
  })

  const activeMessages = active
    ? (messages[active.name] || messages[active.nome] || [])
    : []

  if (!auth) {
    return <AuthScreen onAuth={handleAuth} />
  }

  return (
    <div className="flex h-full w-full overflow-hidden bg-slate-950 text-slate-100">
      <Sidebar
        auth={auth}
        conversations={conversations}
        activeName={active?.name}
        search={search}
        onSearchChange={setSearch}
        onSelectConversation={selectConversation}
        onCreateGroup={() => setShowNewGroup(true)}
        onSearchUsers={() => setShowUserSearch(true)}
        onLogout={handleLogout}
      />

      <main className="flex min-w-0 flex-1 flex-col bg-slate-950">
        {active ? (
          <>
            <ChatHeader
              active={active}
              wsStatus={wsStatus}
              onLeaveGroup={handleLeaveGroup}
              onDeleteGroup={handleDeleteGroup}
              canDeleteGroup={active?.type === 'group' && active?.created_by_user_id === auth.userId}
            />

            <MessageList messages={activeMessages} currentUsername={auth.nome || auth.username || auth.email} listRef={messageListRef} />

            <MessageInput
              value={input}
              onChange={setInput}
              onSend={sendMessage}
              placeholder={`Mensagem para ${active.nome || active.name}...`}
            />
          </>
        ) : (
          <EmptyState />
        )}
      </main>

      {showNewGroup ? (
        <NewGroupModal
          token={auth.token}
          onClose={() => setShowNewGroup(false)}
          onCreated={handleGroupCreated}
          onSendWsAction={sendWsAction}
        />
      ) : null}

      {showUserSearch ? (
        <UserSearchModal
          auth={auth}
          sendWsAction={sendWsAction}
          groupName={active?.type === 'group' ? active.name : null}
          onClose={() => setShowUserSearch(false)}
          onOpenConversation={handleOpenDirectMessage}
          onAddToGroup={handleAddUserToGroup}
        />
      ) : null}
    </div>
  )
}
