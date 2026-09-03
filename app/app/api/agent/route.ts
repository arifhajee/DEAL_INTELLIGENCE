/**
 * POST /api/agent
 *
 * Calls the Snowflake Cortex Agent via REST API with real-time SSE streaming.
 * Uses the agent object endpoint with the sf-context-current-user-token header
 * so the agent's Analyst tool respects the row access policy on document_catalog.
 *
 * Note: The agent's Cortex Search tool queries a pre-built index that does not
 * currently enforce row access policies. A PrPr for RAP support in Cortex Search
 * is pending. Once available, search results will also be filtered by entitlements.
 */
import { getServiceToken } from "@/lib/snowflake"
import { DB, AGENT_NAME, SERVICES_SCHEMA } from "@/lib/db"
import { NextRequest } from "next/server"
import { requireUser, serverError } from "@/lib/api-utils"

export const dynamic = "force-dynamic"

interface AgentMessage {
  role: "user" | "assistant"
  content: { type: "text"; text: string }[]
}

export async function POST(req: NextRequest) {
  const denied = await requireUser()
  if (denied) return denied

  try {
    const { question, history = [] } = await req.json() as {
      question: string
      history?: { role: string; content: string }[]
    }
    if (!question?.trim()) {
      return Response.json({ error: "No question provided" }, { status: 400 })
    }
    if (question.length > 2000) {
      return Response.json({ error: "question too long (max 2000 characters)" }, { status: 400 })
    }

    // Build messages array for the agent
    const messages: AgentMessage[] = []
    for (const h of history.slice(-6)) {
      const role = h.role === "assistant" ? "assistant" : "user"
      messages.push({ role, content: [{ type: "text", text: h.content }] })
    }
    messages.push({ role: "user", content: [{ type: "text", text: question }] })

    // Get tokens for callers-rights auth
    const serviceToken = getServiceToken()
    const callerToken = req.headers.get("sf-context-current-user-token") ?? ""

    if (!serviceToken) {
      return Response.json(
        { error: "No SPCS service token available. Is the app running in Snowflake?" },
        { status: 500 }
      )
    }
    if (!callerToken) {
      return Response.json(
        { error: "No caller token. User authentication required." },
        { status: 401 }
      )
    }

    const host = process.env.SNOWFLAKE_HOST
    if (!host) {
      return Response.json(
        { error: "SNOWFLAKE_HOST not set. App must run in SPCS." },
        { status: 500 }
      )
    }

    const agentUrl = `https://${host}/api/v2/databases/${DB}/schemas/${SERVICES_SCHEMA}/agents/${AGENT_NAME}:run`

    console.log(new Date().toISOString(), "[agent-rest] calling agent, msgCount=", messages.length)

    // Call the Cortex Agent REST API with the service token.
    // The sf-context-current-user-token header passes the caller's identity
    // so the agent's Analyst tool executes SQL in the caller's context (RAP applies).
    const agentResp = await fetch(agentUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${serviceToken}`,
        "X-Snowflake-Authorization-Token-Type": "OAUTH",
        "Content-Type": "application/json",
        "Accept": "text/event-stream",
        "sf-context-current-user-token": callerToken,
      },
      body: JSON.stringify({ messages, stream: true }),
    })

    if (!agentResp.ok) {
      const errBody = await agentResp.text()
      const errMsg = `Agent REST ${agentResp.status}: ${errBody.slice(0, 300)}`
      console.error(new Date().toISOString(), "[agent-rest] error:", errMsg)
      return Response.json(
        { error: errMsg },
        { status: 502 }
      )
    }

    if (!agentResp.body) {
      return Response.json({ error: "Agent returned no response body" }, { status: 502 })
    }

    // Stream SSE events from the agent directly to the client.
    const encoder = new TextEncoder()
    const agentReader = agentResp.body.getReader()
    const decoder = new TextDecoder()
    let toolUsed = "Agent"
    let sentAnyText = false

    const stream = new ReadableStream<Uint8Array>({
      async start(controller) {
        let buffer = ""
        let currentEvent = ""
        try {
          while (true) {
            const { done, value } = await agentReader.read()
            if (done) break
            buffer += decoder.decode(value, { stream: true })
            const lines = buffer.split("\n")
            buffer = lines.pop() ?? ""

            for (const line of lines) {
              if (line.startsWith("event:")) {
                currentEvent = line.slice(6).trim()
                continue
              }
              if (!line.startsWith("data:")) continue
              const payload = line.slice(5).trim()
              if (payload === "[DONE]") continue

              try {
                const data = JSON.parse(payload)

                if (currentEvent === "error") {
                  const errMsg = data.message ?? JSON.stringify(data)
                  sentAnyText = true
                  controller.enqueue(encoder.encode(
                    `data: ${JSON.stringify({ delta: `[Agent error: ${errMsg}]`, toolUsed, done: false })}\n\n`
                  ))
                } else if (currentEvent === "response.text.delta" && data.text) {
                  sentAnyText = true
                  controller.enqueue(encoder.encode(
                    `data: ${JSON.stringify({ delta: data.text, toolUsed, done: false })}\n\n`
                  ))
                } else if (currentEvent === "response.tool_use") {
                  const t = data.type ?? ""
                  const n = data.name ?? ""
                  if (t.includes("analyst") || t.includes("sql") || n.includes("analyst") || n.includes("sql")) {
                    toolUsed = "Analytics"
                  } else if (t.includes("search") || n.includes("search")) {
                    toolUsed = "Search"
                  }
                  controller.enqueue(encoder.encode(
                    `data: ${JSON.stringify({ status: `Using ${toolUsed}...`, toolUsed, done: false })}\n\n`
                  ))
                } else if (currentEvent === "response.table" && data.result_set) {
                  const rs = data.result_set
                  const columns = rs.resultSetMetaData?.rowType?.map((r: { name: string }) => r.name) ?? []
                  const rows = rs.data ?? []
                  if (columns.length > 0 && rows.length > 0) {
                    controller.enqueue(encoder.encode(
                      `data: ${JSON.stringify({ resultSet: { columns, rows, title: data.title }, toolUsed, done: false })}\n\n`
                    ))
                  }
                } else if (currentEvent === "response.tool_result.analyst.delta" && data.delta?.result_set) {
                  const rs = data.delta.result_set
                  const columns = rs.resultSetMetaData?.rowType?.map((r: { name: string }) => r.name) ?? []
                  const rows = rs.data ?? []
                  if (columns.length > 0 && rows.length > 0) {
                    controller.enqueue(encoder.encode(
                      `data: ${JSON.stringify({ resultSet: { columns, rows }, toolUsed, done: false })}\n\n`
                    ))
                  }
                } else if (currentEvent === "response.status") {
                  const msg = data.message ?? ""
                  if (msg) {
                    controller.enqueue(encoder.encode(
                      `data: ${JSON.stringify({ status: msg, toolUsed, done: false })}\n\n`
                    ))
                  }
                } else if (currentEvent === "response" && data.content) {
                  if (!sentAnyText) {
                    const parts = data.content
                      .filter((c: { type: string }) => c.type === "text")
                      .map((c: { text?: string }) => c.text ?? "")
                    const fullText = parts.join("\n").trim()
                    if (fullText) {
                      sentAnyText = true
                      controller.enqueue(encoder.encode(
                        `data: ${JSON.stringify({ delta: fullText, toolUsed, done: false })}\n\n`
                      ))
                    }
                  }
                  for (const item of data.content) {
                    if (item.type === "table" && item.table?.result_set) {
                      const rs = item.table.result_set
                      const columns = rs.resultSetMetaData?.rowType?.map((r: { name: string }) => r.name) ?? []
                      const rows = rs.data ?? []
                      if (columns.length > 0 && rows.length > 0) {
                        controller.enqueue(encoder.encode(
                          `data: ${JSON.stringify({ resultSet: { columns, rows, title: item.table.title }, toolUsed, done: false })}\n\n`
                        ))
                      }
                    }
                  }
                }
              } catch (parseErr) { console.warn("[agent-sse] failed to parse event:", currentEvent, parseErr) }

              currentEvent = ""
            }
          }

          if (!sentAnyText) {
            controller.enqueue(encoder.encode(
              `data: ${JSON.stringify({ delta: "[Agent returned no text. Check /api/agent/debug]", toolUsed, done: false })}\n\n`
            ))
          }

          controller.enqueue(encoder.encode(
            `data: ${JSON.stringify({ delta: "", toolUsed, done: true })}\n\n`
          ))
          controller.close()
        } catch (e) {
          const errMsg = e instanceof Error ? e.message : String(e)
          console.error(new Date().toISOString(), "[agent-rest] stream error:", errMsg)
          controller.enqueue(encoder.encode(
            `data: ${JSON.stringify({ delta: `\n\n[Stream error: ${errMsg}]`, toolUsed, done: true })}\n\n`
          ))
          controller.close()
        }
      },
    })

    return new Response(stream, {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache, no-transform",
        "Connection": "keep-alive",
        "X-Accel-Buffering": "no",
      },
    })
  } catch (e) {
    console.error(new Date().toISOString(), "[agent] error", e instanceof Error ? e.message.slice(0, 200) : String(e))
    return serverError(e)
  }
}
