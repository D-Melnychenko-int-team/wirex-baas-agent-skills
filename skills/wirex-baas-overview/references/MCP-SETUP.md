# Wirex BaaS MCP Server Setup

The Wirex BaaS Model Context Protocol (MCP) server provides AI-powered development tools with direct access to the Wirex BaaS API documentation, endpoint specifications, and code generation assistance.

**MCP Server URL:** `https://docs.wirexapp.com/mcp`

---

## What the MCP Server Provides

| Capability | Description |
|---|---|
| **API Documentation Access** | Query endpoint specifications, request/response schemas, parameter descriptions, and usage constraints directly from your AI tool. |
| **Documentation Search** | Full-text search across the entire Wirex BaaS documentation corpus. Find relevant guides, tutorials, and API references by keyword or concept. |
| **Real-Time Data** | Access current platform configuration, supported tokens, chain IDs, and environment details without leaving your editor. |
| **Code Generation Assistance** | Generate integration code snippets, authentication flows, and complete API call examples in multiple languages. |

---

## Setup Instructions

All tools use the same MCP server URL. The JSON config is identical across tools (except Windsurf uses `serverUrl` and VS Code uses a different top-level key):

```json
{
  "mcpServers": {
    "wirex-baas": {
      "url": "https://docs.wirexapp.com/mcp"
    }
  }
}
```

### Configuration File Locations

| Tool | Config File | Notes |
|------|------------|-------|
| **Cursor** | `~/.cursor/mcp.json` | Uses `url` |
| **Claude Desktop** (macOS) | `~/Library/Application Support/Claude/claude_desktop_config.json` | Uses `url` |
| **Claude Desktop** (Windows) | `%APPDATA%\Claude\claude_desktop_config.json` | Uses `url` |
| **Claude Code** | `.claude/mcp.json` (project) or CLI: `claude mcp add wirex-baas --transport sse "https://docs.wirexapp.com/mcp"` | Uses `url` |
| **Windsurf** (macOS) | `~/.codeium/windsurf/mcp_config.json` | Uses `serverUrl` instead of `url` |
| **Windsurf** (Windows) | `%USERPROFILE%\.codeium\windsurf\mcp_config.json` | Uses `serverUrl` instead of `url` |
| **VS Code + Copilot** | `.vscode/settings.json` | Top-level key: `"github.copilot.chat.mcpServers"` instead of `"mcpServers"` |

After saving, restart the application to activate the MCP server.

---

## Testing the Connection

After configuring your tool, verify the MCP server is working by asking your AI assistant a question about Wirex BaaS:

**Test prompts:**

- "What endpoints does Wirex BaaS provide for user creation?"
- "Show me how to authenticate with the Wirex BaaS API."
- "What are the supported tokens on the Base network?"
- "How do I issue a virtual Visa card through Wirex BaaS?"

If the MCP server is connected, the AI tool will use it to retrieve accurate, up-to-date information from the Wirex BaaS documentation.

### Troubleshooting

| Issue | Solution |
|---|---|
| MCP tools not appearing | Restart the application after saving the configuration file. |
| Connection timeout | Verify network access to `https://docs.wirexapp.com/mcp`. Check firewall or proxy settings. |
| Authentication errors | The MCP server is publicly accessible for documentation queries. No API key is required for MCP access. |
| Stale data | The MCP server serves the latest published documentation. Clear your tool's cache if responses seem outdated. |

---

## Usage Examples

### Exploring Endpoints

Ask your AI assistant:

> "Using Wirex BaaS docs, show me the request and response format for POST /api/v1/token"

The MCP server will retrieve the full endpoint specification including headers, body parameters, and response schema.

### Generating Integration Code

Ask your AI assistant:

> "Generate a Python function to authenticate with Wirex BaaS and create a new user, using the sandbox environment"

The MCP server provides the AI tool with accurate endpoint details so the generated code uses correct URLs, headers, and parameter formats.

### Searching Documentation

Ask your AI assistant:

> "Search Wirex BaaS docs for information about KYC verification webhooks"

The MCP server performs a full-text search and returns relevant documentation sections.
