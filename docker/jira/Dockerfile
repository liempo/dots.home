# [mcp-server-jira-cloud](https://www.npmjs.com/package/mcp-server-jira-cloud) (stdio) behind
# [supergateway](https://www.npmjs.com/package/supergateway) streamable HTTP for MCP clients on `mcp-net`.
FROM node:22-bookworm-slim

ENV NPM_CONFIG_UPDATE_NOTIFIER=false

RUN npm install -g supergateway@3.4.3 mcp-server-jira-cloud@1.1.1 \
  && npm cache clean --force

EXPOSE 8000

CMD ["supergateway", "--stdio", "mcp-server-jira-cloud", "--outputTransport", "streamableHttp", "--port", "8000", "--streamableHttpPath", "/mcp", "--healthEndpoint", "/healthz"]
