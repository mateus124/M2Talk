export default function MessageInput({ value, onChange, onSend, placeholder }) {
  const disabled = !value.trim()

  return (
    <form
      onSubmit={(event) => {
        event.preventDefault()
        onSend()
      }}
      className="flex items-end gap-3 border-t border-white/10 bg-slate-950/80 px-5 py-4 backdrop-blur-xl"
    >
      <textarea
        className="min-h-[48px] max-h-[120px] flex-1 resize-none rounded-2xl border border-white/10 bg-slate-900 px-4 py-3 text-sm leading-6 text-white outline-none transition placeholder:text-slate-500 focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20"
        placeholder={placeholder}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        onKeyDown={(event) => {
          if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault()
            onSend()
          }
        }}
        rows={1}
      />

      <button
        type="submit"
        disabled={disabled}
        className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-blue-500 text-lg text-white transition hover:bg-blue-400 disabled:cursor-not-allowed disabled:bg-slate-700"
      >
        ➤
      </button>
    </form>
  )
}