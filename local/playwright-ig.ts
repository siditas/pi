import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFileSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

// Scripts live next to this file in the repo; Windows runs them via \\wsl.localhost\...
const HERE = dirname(fileURLToPath(import.meta.url));
const winPath = (p: string) => execFileSync("wslpath", ["-w", p]).toString().trim();
const PORT = 9222;        // Chromium CDP (loopback-only on Windows)
const RELAY = 9223;       // cdp-relay.ps1 exposes it to WSL on 0.0.0.0
const KEEP = new Set(["browser_tabs", "browser_snapshot", "browser_click", "browser_type",
                      "browser_navigate", "browser_evaluate", "browser_take_screenshot"]);

function windowsHostIp(): string {
  // WSL2: Windows host is the default gateway (unless mirrored networking, then localhost works)
  const m = execFileSync("ip", ["route"]).toString().match(/default via (\S+)/);
  return m?.[1] ?? "127.0.0.1";
}

export default async function (pi: ExtensionAPI) {
  // 1. Ensure Chromium is up (PowerShell does install + launch + wait; idempotent)
  execFileSync("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", winPath(join(HERE, "start-chromium.ps1")), "-Port", String(PORT)], { stdio: "inherit" });

  // 2. Attach Playwright MCP to it over CDP
  const client = new Client({ name: "pi", version: "1.0" });
  await client.connect(new StdioClientTransport({
    command: "npx",
    args: ["-y", "@playwright/mcp@latest", "--cdp-endpoint", `http://${windowsHostIp()}:${RELAY}`],
  }));

  // 3. Mirror a trimmed tool set into pi
  const { tools } = await client.listTools();
  for (const t of tools.filter(t => KEEP.has(t.name))) {
    pi.registerTool({
      name: t.name,
      label: t.name,
      description: t.description ?? t.name,
      parameters: t.inputSchema as any,
      async execute(_id, params, signal) {
        await new Promise(r => setTimeout(r, 1500)); // pace IG interactions
        const res = await client.callTool({ name: t.name, arguments: params }, undefined, { signal });
        const text = (res.content as any[]).map(c => c.type === "text" ? c.text : `[${c.type}]`).join("\n");
        return { content: [{ type: "text", text: text.slice(0, 20_000) }], details: {} };
      },
    });
  }
  pi.on("session_shutdown", () => client.close());
}
