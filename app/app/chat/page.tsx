"use client"

import { Suspense, useState, useRef, useEffect, useCallback } from "react"
import { useSearchParams } from "next/navigation"
import { Send, Bot, User, Zap, BarChart2, RotateCcw, ThumbsUp, ThumbsDown, Cpu } from "lucide-react"
import { PageHeader } from "@/components/page-header"
import { showToast } from "@/components/toast"
import { useDocumentPreview, DocLoadingIndicator } from "@/components/doc-download"
import ReactMarkdown, { Components } from "react-markdown"
import remarkGfm from "remark-gfm"
import { ResultChart } from "./_components/result-chart"

interface Message {
  role: "user" | "assistant"
  content: string
  toolUsed?: string
  isError?: boolean
  resultSet?: { columns: string[]; rows: (string | number | null)[][]; title?: string }
}

const QUICK_Q = [
  "What are the key risks in our Digital Infrastructure investments?",
  "How many deals by sector are in due diligence this year?",
  "Find coverage opinions from the last 90 days",
  "What's the total reserve exposure for open claims?",
]

export default function ChatPage() {
  return (
    <Suspense fallback={<div className="sf-card p-10 text-center text-slate-400">Loading…</div>}>
      <ChatPageInner />
    </Suspense>
  )
}

function ChatPageInner() {
  const searchParams = useSearchParams()
  const initQ = searchParams.get("q") ?? ""

  const [messages, setMessages]   = useState<Message[]>([])
  const [input, setInput]         = useState("")
  const [loading, setLoading]     = useState(false)
  const [feedback, setFeedback]   = useState<Record<number, "up" | "down">>({})
  const bottomRef = useRef<HTMLDivElement>(null)
  const { open: openDoc, loading: docLoading, ModalComponent: DocModal } = useDocumentPreview()

  // Resolve a filename to its full file_path from the document catalog, then open preview
  async function openDocByFilename(filename: string) {
    try {
      const res = await fetch(`/api/documents?search=${encodeURIComponent(filename)}&limit=1`)
      if (res.ok) {
        const data = await res.json()
        const rows = data.rows ?? data
        if (Array.isArray(rows) && rows.length > 0) {
          const fp = rows[0].FILE_PATH ?? rows[0].file_path ?? rows[0].file_path
          if (fp) { openDoc(fp); return }
        }
      }
      showToast(`Could not find document: ${filename}`, "error")
    } catch {
      showToast("Failed to resolve document reference", "error")
    }
  }

  // Regex to detect document file references (e.g., "CY-loss_run-meridian-CY-2023-7939.pdf")
  const DOC_REF_PATTERN = /([\w-]+\.(?:pdf|docx|tiff?|png|jpg|jpeg))\b/gi
  // Pattern for page-level citations: [filename.pdf, p.3]
  const PAGE_CITATION_PATTERN = /\[([^\]]+\.(?:pdf|docx|tiff?|png|jpg|jpeg)),\s*p\.(\d+)\]/gi

  // Custom markdown components that make document filenames clickable
  const mdComponents: Components = {
    // Intercept text nodes to linkify document references
    p: ({ children, ...props }) => {
      return <p {...props}>{linkifyDocRefs(children)}</p>
    },
    li: ({ children, ...props }) => {
      return <li {...props}>{linkifyDocRefs(children)}</li>
    },
    strong: ({ children, ...props }) => {
      return <strong {...props}>{linkifyDocRefs(children)}</strong>
    },
    table: ({ children, ...props }) => {
      return <table className="border-collapse border border-slate-300 my-2 text-sm w-full" {...props}>{children}</table>
    },
    th: ({ children, ...props }) => {
      return <th className="border border-slate-300 px-3 py-1.5 bg-slate-100 font-semibold text-left" {...props}>{children}</th>
    },
    td: ({ children, ...props }) => {
      return <td className="border border-slate-300 px-3 py-1.5" {...props}>{children}</td>
    },
  }

  // Recursively process children to find and linkify document filename references
  function linkifyDocRefs(children: React.ReactNode): React.ReactNode {
    if (!children) return children
    if (typeof children === "string") {
      // First handle [filename.pdf, p.N] page citations
      const pageCitationRegex = /\[([^\]]+\.(?:pdf|docx|tiff?|png|jpg|jpeg)),\s*p\.(\d+)\]/gi
      const parts: React.ReactNode[] = []
      let lastIndex = 0
      let match: RegExpExecArray | null

      const tempStr = children
      pageCitationRegex.lastIndex = 0
      while ((match = pageCitationRegex.exec(tempStr)) !== null) {
        if (match.index > lastIndex) {
          parts.push(tempStr.slice(lastIndex, match.index))
        }
        const filename = match[1]
        const pageNum = match[2]
        parts.push(
          <button
            key={`pc-${match.index}`}
            onClick={() => openDocByFilename(filename)}
            className="inline-flex items-center gap-0.5 text-xs text-blue-600 hover:text-blue-800 bg-blue-50 hover:bg-blue-100 border border-blue-200 px-1.5 py-0.5 rounded font-medium mx-0.5"
          >
            {filename}, p.{pageNum}
          </button>
        )
        lastIndex = match.index + match[0].length
      }
      if (parts.length > 0) {
        if (lastIndex < tempStr.length) parts.push(tempStr.slice(lastIndex))
        // Also linkify remaining plain doc refs in non-citation parts
        return parts.flatMap((p, i) => typeof p === "string" ? [linkifyDocRefs(p)] : [p])
      }

      // Fall back to plain filename linkification
      const fileParts = children.split(DOC_REF_PATTERN)
      if (fileParts.length <= 1) return children
      const testPattern = /[\w-]+\.(?:pdf|docx|tiff?|png|jpg|jpeg)$/i
      return fileParts.map((part, idx) => {
        if (testPattern.test(part)) {
          return (
            <button
              key={idx}
              onClick={() => openDocByFilename(part)}
              className="inline text-blue-600 hover:text-blue-800 underline decoration-blue-300 hover:decoration-blue-600 cursor-pointer font-medium"
              title={`View: ${part}`}
            >
              {part}
            </button>
          )
        }
        return part
      })
    }
    if (Array.isArray(children)) {
      return children.map((child, i) => <span key={i}>{linkifyDocRefs(child)}</span>)
    }
    return children
  }

  useEffect(() => {
    if (initQ) sendMessage(initQ)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" })
  }, [messages, loading])

  async function sendMessage(text = input) {
    const q = text.trim()
    if (!q) return
    setInput("")
    const historySnapshot = messages
    setMessages(prev => [...prev, { role: "user", content: q }])
    setLoading(true)
    try {
      const res = await fetch("/api/agent", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ question: q, history: historySnapshot }),
      })

      if (!res.ok) {
        const data = await res.json().catch(() => ({ error: "Request failed" }))
        showToast(data.error ?? "Chat request failed — please try again", "error")
        setMessages(prev => [...prev, { role: "assistant", content: data.error ?? "Request failed", isError: true }])
        setLoading(false)
        return
      }

      // Stream SSE response
      if (res.headers.get("content-type")?.includes("text/event-stream") && res.body) {
        // Add an empty assistant message that we'll update progressively
        setMessages(prev => [...prev, { role: "assistant", content: "", toolUsed: undefined }])
        setLoading(false) // hide bouncing dots — we're now streaming

        const reader = res.body.getReader()
        const decoder = new TextDecoder()
        let buffer = ""

        while (true) {
          const { done, value } = await reader.read()
          if (done) break

          buffer += decoder.decode(value, { stream: true })
          const lines = buffer.split("\n")
          buffer = lines.pop() ?? ""

          for (const line of lines) {
            if (!line.startsWith("data:")) continue
            const payload = line.slice(5).trim()
            if (payload === "[DONE]") continue
            try {
              const event = JSON.parse(payload)
              if (event.error) {
                setMessages(prev => {
                  const copy = [...prev]
                  copy[copy.length - 1] = { role: "assistant", content: "Agent unavailable — please try again.", isError: true }
                  return copy
                })
                return
              }
              if (event.done) {
                // Final event — update toolUsed
                setMessages(prev => {
                  const copy = [...prev]
                  const last = copy[copy.length - 1]
                  copy[copy.length - 1] = { ...last, toolUsed: event.toolUsed }
                  return copy
                })
              } else if (event.delta) {
                // Append delta text to the last message (clear status placeholder if present)
                setMessages(prev => {
                  const copy = [...prev]
                  const last = copy[copy.length - 1]
                  const currentContent = last.content.startsWith("_") && last.content.endsWith("_") ? "" : last.content
                  copy[copy.length - 1] = { ...last, content: currentContent + event.delta, toolUsed: event.toolUsed }
                  return copy
                })
              } else if (event.resultSet) {
                setMessages(prev => {
                  const copy = [...prev]
                  const last = copy[copy.length - 1]
                  copy[copy.length - 1] = { ...last, resultSet: event.resultSet }
                  return copy
                })
              } else if (event.status) {
                // Status update (e.g. "Using Search...", "Planning the next steps")
                setMessages(prev => {
                  const copy = [...prev]
                  const last = copy[copy.length - 1]
                  // Only update status if no real text content has arrived yet
                  const isStillPending = !last.content || (last.content.startsWith("_") && last.content.endsWith("_"))
                  if (isStillPending) {
                    copy[copy.length - 1] = { ...last, content: `_${event.status}_`, toolUsed: event.toolUsed }
                  }
                  return copy
                })
              }
            } catch (e) { console.warn("[chat-sse] parse error", e) }
          }
        }
      } else {
        // Non-streaming fallback (shouldn't happen but handle gracefully)
        const data = await res.json()
        setMessages(prev => [...prev, { role: "assistant", content: data.answer ?? "No response", toolUsed: data.toolUsed }])
        setLoading(false)
      }
    } catch (err) {
      showToast("Network error — please check your connection", "error")
      setMessages(prev => [...prev, { role: "assistant", content: err instanceof Error ? err.message : "Unknown error", isError: true }])
      setLoading(false)
    }
  }

  return (
    <div className="max-w-3xl mx-auto flex flex-col h-[calc(100vh-9rem)]">
      {DocModal}
      <DocLoadingIndicator loading={docLoading} />
      <div className="mb-4">
        <PageHeader title="Doc Intelligence Agent" icon={Cpu} subtitle="Find documents, read content, or ask questions that span search and data">
          {messages.length > 0 && (
            <button
              className="sf-btn-secondary flex items-center gap-1.5"
              onClick={() => setMessages([])}
            >
              <RotateCcw size={13} /> New conversation
            </button>
          )}
        </PageHeader>
      </div>

      {/* Chat thread */}
      <div className="flex-1 overflow-y-auto space-y-4 pb-4">
        {messages.length === 0 && (
          <div className="sf-card p-6 text-center">
            <Bot size={36} className="text-[var(--brand-primary)] mx-auto mb-3" />
            <h2 className="font-semibold text-slate-700 mb-1">Doc Intelligence Agent</h2>
            <p className="text-sm text-slate-500 mb-4">Powered by <span className="font-mono text-[11px] bg-slate-100 px-1.5 py-0.5 rounded">DEAL_INTELLIGENCE_AGENT</span> — ask anything about your documents</p>
            <div className="grid grid-cols-1 gap-2">
              {QUICK_Q.map(q => (
                <button
                  key={q}
                  className="text-left text-sm px-3 py-2 rounded-lg border border-slate-200 hover:border-[var(--brand-primary)] hover:bg-[var(--brand-pale)] text-slate-600 transition-all"
                  onClick={() => sendMessage(q)}
                >
                  💬 {q}
                </button>
              ))}
            </div>
          </div>
        )}

        {messages.map((msg, i) => (
          <div key={i} className={`flex gap-3 ${msg.role === "user" ? "flex-row-reverse" : ""}`}>
            <div className={`w-8 h-8 rounded-full flex items-center justify-center shrink-0 ${msg.role === "user" ? "bg-[var(--brand-primary)] text-white" : "bg-[var(--brand-light)] text-[var(--brand-dark)]"}`}>
              {msg.role === "user" ? <User size={15} /> : <Bot size={15} />}
            </div>
            <div className={`flex-1 max-w-[85%] ${msg.role === "user" ? "items-end" : "items-start"} flex flex-col gap-1`}>
              {msg.toolUsed && msg.role === "assistant" && (
                <div className="flex items-center gap-1 text-[10px] font-semibold px-2 py-0.5 rounded-full bg-[var(--brand-light)] text-[var(--brand-dark)] w-fit">
                  {msg.toolUsed?.startsWith("Analytics") ? <BarChart2 size={10} /> : <Zap size={10} />}
                  via {msg.toolUsed}
                </div>
              )}
              <div className={`px-4 py-3 rounded-2xl text-sm leading-relaxed ${
                msg.role === "user"
                  ? "bg-[var(--brand-dark)] text-white rounded-tr-sm whitespace-pre-wrap"
                  : msg.isError
                    ? "bg-red-50 border border-red-200 text-red-700 italic rounded-tl-sm whitespace-pre-wrap"
                    : "bg-white border border-slate-200 text-slate-800 rounded-tl-sm prose prose-sm prose-slate max-w-none"
              }`}>
                {msg.role === "assistant" && !msg.isError ? (
                  msg.content.startsWith("_") && msg.content.endsWith("_") && !msg.content.slice(1, -1).includes("_") ? (
                    <div className="flex items-center gap-2 text-slate-500 italic">
                      <svg className="animate-spin h-3.5 w-3.5 text-[var(--brand-primary)]" viewBox="0 0 24 24" fill="none">
                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                      </svg>
                      <span className="animate-pulse">{msg.content.slice(1, -1)}</span>
                    </div>
                  ) : (
                    <>
                      <ReactMarkdown remarkPlugins={[remarkGfm]} components={mdComponents}>{msg.content}</ReactMarkdown>
                      {msg.resultSet && <ResultChart columns={msg.resultSet.columns} rows={msg.resultSet.rows} title={msg.resultSet.title} />}
                    </>
                  )
                ) : (
                  msg.content
                )}
              </div>
              {msg.role === "assistant" && (
                <div className="flex gap-1">
                  <button
                    className={`p-1 rounded transition-colors disabled:opacity-40 disabled:cursor-not-allowed ${feedback[i] === "up" ? "text-green-600" : "text-slate-300 hover:text-slate-500"}`}
                    disabled={!!feedback[i]}
                    onClick={async () => {
                      setFeedback(f => ({ ...f, [i]: "up" }))
                      await fetch("/api/feedback", {
                        method: "POST",
                        headers: { "Content-Type": "application/json" },
                        body: JSON.stringify({ filePath: `chat_response_${i}`, feedbackType: "thumbs_up", queryText: messages[i-1]?.content }),
                      }).catch(() => {})
                      showToast("Thanks for the feedback!", "success")
                    }}
                  ><ThumbsUp size={13} /></button>
                  <button
                    className={`p-1 rounded transition-colors disabled:opacity-40 disabled:cursor-not-allowed ${feedback[i] === "down" ? "text-red-500" : "text-slate-300 hover:text-slate-500"}`}
                    disabled={!!feedback[i]}
                    onClick={async () => {
                      setFeedback(f => ({ ...f, [i]: "down" }))
                      await fetch("/api/feedback", {
                        method: "POST",
                        headers: { "Content-Type": "application/json" },
                        body: JSON.stringify({ filePath: `chat_response_${i}`, feedbackType: "thumbs_down", queryText: messages[i-1]?.content }),
                      }).catch(() => {})
                      showToast("Feedback noted — we'll use this to improve", "info")
                    }}
                  ><ThumbsDown size={13} /></button>
                </div>
              )}
            </div>
          </div>
        ))}

        {loading && (
          <div className="flex gap-3">
            <div className="w-8 h-8 rounded-full bg-[var(--brand-light)] flex items-center justify-center">
              <Bot size={15} className="text-[var(--brand-dark)]" />
            </div>
            <div className="bg-white border border-slate-200 rounded-2xl rounded-tl-sm px-4 py-3">
              <div className="flex gap-1">
                {[0,1,2].map(d => (
                  <div key={d} className="w-2 h-2 bg-[var(--brand-primary)] rounded-full animate-bounce" style={{ animationDelay: `${d * 0.15}s` }} />
                ))}
              </div>
            </div>
          </div>
        )}
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <div className="sf-card p-3 flex gap-2">
        <input
          className="flex-1 text-sm px-3 py-2 border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-[var(--brand-primary)] focus:border-transparent"
          placeholder="Ask the Doc Intelligence Agent…"
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyDown={e => e.key === "Enter" && !e.shiftKey && sendMessage()}
          disabled={loading}
        />
        <button
          className="sf-btn-primary flex items-center gap-1.5 disabled:opacity-50"
          onClick={() => sendMessage()}
          disabled={loading || !input.trim()}
        >
          <Send size={14} /> Send
        </button>
      </div>
    </div>
  )
}
