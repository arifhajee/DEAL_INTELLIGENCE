/**
 * Snowflake database name for the DealIntel pipeline.
 */
export const DB = process.env.DEAL_INTEL_DATABASE ?? "DEAL_INTEL"

/**
 * Schema for AI services (agent, search, semantic view).
 */
export const SERVICES_SCHEMA = process.env.DEAL_INTEL_SERVICES_SCHEMA ?? "SERVICES"

/**
 * Cortex Search service name (default: deal_search_svc).
 */
export const SEARCH_SVC = process.env.DEAL_INTEL_SEARCH_SVC ?? "deal_search_svc"

/**
 * Page-level Cortex Search service name (for intra-document search and page citations).
 */
export const PAGE_SEARCH_SVC = process.env.DEAL_INTEL_PAGE_SEARCH_SVC ?? "deal_page_search_svc"

/**
 * Cortex LLM model name for conversational queries (default: claude-sonnet-4-5).
 */
export const CORTEX_MODEL = process.env.DEAL_INTEL_CORTEX_MODEL ?? "claude-sonnet-4-5"

/**
 * Cortex Agent name (default: deal_intelligence_agent).
 */
export const AGENT_NAME = process.env.DEAL_INTEL_AGENT_NAME ?? "deal_intelligence_agent"

/**
 * Snowflake role names for RBAC checks.
 */
export const ROLE_ADMIN = process.env.DEAL_INTEL_ROLE_ADMIN ?? "DEAL_INTEL_ADMIN"
export const ROLE_USER = process.env.DEAL_INTEL_ROLE_USER ?? "DEAL_INTEL_USER"
export const ROLE_PIPELINE = process.env.DEAL_INTEL_ROLE_PIPELINE ?? "DEAL_INTEL_PIPELINE"
