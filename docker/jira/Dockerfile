# Two stdio MCPs behind [supergateway](https://www.npmjs.com/package/supergateway) (streamable HTTP):
# - [mcp-server-jira-cloud](https://www.npmjs.com/package/mcp-server-jira-cloud) — issues, JQL, comments
# - [hoibui/jira-mcp-server](https://github.com/hoibui/jira-mcp-server) (`jira-attachments-mcp`) — list/download attachments
#
# Compose runs one gateway per service (different host ports, same `mcp-net`).
FROM node:22-bookworm-slim

ENV NPM_CONFIG_UPDATE_NOTIFIER=false

# Pinned commit (npm package not published); GitHub archive top-level dir is `jira-mcp-server-<ref>`.
ARG JIRA_ATTACHMENTS_MCP_REF=19709448b03fb05437561e1c094ca0e64f104166

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/* \
  && curl -fsSL "https://github.com/hoibui/jira-mcp-server/archive/${JIRA_ATTACHMENTS_MCP_REF}.tar.gz" \
    | tar xz -C /opt \
  && mv "/opt/jira-mcp-server-${JIRA_ATTACHMENTS_MCP_REF}" /opt/jira-attachments-mcp \
  && cd /opt/jira-attachments-mcp \
  && npm install --omit=dev \
  && ln -sf /opt/jira-attachments-mcp/dist/index.js /usr/local/bin/jira-attachments-mcp \
  && chmod +x /usr/local/bin/jira-attachments-mcp \
  && npm install -g supergateway@3.4.3 mcp-server-jira-cloud@1.1.1 \
  && npm cache clean --force

EXPOSE 8000

# Default: main Jira Cloud MCP (override in compose for attachments service).
CMD ["supergateway", "--stdio", "mcp-server-jira-cloud", "--outputTransport", "streamableHttp", "--port", "8000", "--streamableHttpPath", "/mcp", "--healthEndpoint", "/healthz"]
