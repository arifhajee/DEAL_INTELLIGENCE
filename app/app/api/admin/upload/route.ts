import { querySnowflake } from "@/lib/snowflake"
import { DB } from "@/lib/db"
import { NextRequest } from "next/server"
import { requireAdmin, escIdent, serverError } from "@/lib/api-utils"
import { writeFile, unlink } from "fs/promises"
import { join } from "path"
import { randomUUID } from "crypto"

export const dynamic = "force-dynamic"

export async function POST(req: NextRequest) {
  const denied = await requireAdmin()
  if (denied) return denied

  try {
    const formData = await req.formData()
    const file = formData.get("file") as File | null
    const stage = escIdent((formData.get("stage") as string) || "sample_stage")

    if (!file) {
      return Response.json({ error: "No file provided" }, { status: 400 })
    }

    const allowedTypes = [".pdf", ".tiff", ".tif", ".docx", ".pptx", ".jpg", ".jpeg", ".png", ".html", ".txt"]
    const ext = "." + file.name.split(".").pop()?.toLowerCase()
    if (!allowedTypes.includes(ext)) {
      return Response.json({ error: `File type ${ext} not supported. Allowed: ${allowedTypes.join(", ")}` }, { status: 400 })
    }

    if (file.size > 50 * 1024 * 1024) {
      return Response.json({ error: "File too large (max 50MB)" }, { status: 400 })
    }

    // Write to temp file
    const tmpPath = join("/tmp", `upload_${randomUUID()}${ext}`)
    const buffer = Buffer.from(await file.arrayBuffer())
    await writeFile(tmpPath, buffer)

    try {
      // PUT to stage
      const stagePath = `@${DB}.DATA.${stage}/documents/`
      await querySnowflake(
        `PUT 'file://${tmpPath}' '${stagePath}' AUTO_COMPRESS=FALSE OVERWRITE=TRUE`,
        { callersRights: true }
      )

      // Refresh stage directory listing
      await querySnowflake(
        `ALTER STAGE ${DB}.DATA.${stage} REFRESH`,
        { callersRights: true }
      )

      // Auto-register the new file
      await querySnowflake(
        `CALL ${DB}.DATA.sp_register_new_files()`,
        { callersRights: true }
      )

      return Response.json({
        ok: true,
        fileName: file.name,
        filePath: `documents/${file.name}`,
        stage,
        size: file.size,
      })
    } finally {
      await unlink(tmpPath).catch(() => {})
    }
  } catch (e) {
    console.error("[upload]", e)
    return serverError(e)
  }
}
