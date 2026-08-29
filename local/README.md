# Local llama.cpp tuning for pi

Config and tooling for running pi against Qwen3.6-35B-A3B (Q4_K_M) on an RTX 5080 Laptop 16 GB + Core Ultra 9 275HX under WSL2.

- `start-llama.sh` — tuned llama-server launch (`--n-cpu-moe 12 --no-mmap -t 8 -tb 8`, 32k ctx). Extra args pass through.
- `srv-sweep.sh` — server-side benchmark: real 1.5k-token prompt, prompt cache off, timings read from the server log. Edit the config list to sweep.
- `models.json` — pi provider `local-llama`; copy to `~/.pi/agent/models.json`. `thinkingFormat: "qwen-chat-template"` is required for thinking-off to reach llama-server.

## Results (2026-08-29)

| config | prompt tok/s | gen tok/s |
|---|---|---|
| original (24 threads, mmap, ncmoe 14) | — | 12 |
| `-t 8`, ncmoe 14 | 888 | 53 |
| `-t 8`, ncmoe 13 | 985 | 78 |
| `-t 8`, ncmoe 14, `--no-mmap` | 1655 | 73 |
| **`-t 8`, ncmoe 12, `--no-mmap`** | **1770** | **76** |
| ncmoe ≤ 11 | VRAM overflow, ~8x collapse | |

`npm run eval -- --provider local-llama --model qwen3.6-35b-a3b-heretic`: 3/3 pass in 76 s (was 2/3, one timeout at 120 s, before `--no-mmap` and the thinking fix).

Do not use the groxaxo IQ4_XS quant of this model — it emits garbage on every prompt (checksum matches HF; the file itself is bad).

Paths in the scripts are absolute to this machine (`/root/models/...`, `/root/llama.cpp/build/bin`).

## Playwright MCP from WSL (browser tools in pi)

`playwright-ig.ts` (goes in `~/.pi/agent/extensions/`) launches a Windows Chromium via `start-chromium.ps1`, attaches `@playwright/mcp` to it over CDP, and mirrors 7 `browser_*` tools into pi.

Headed Chrome ignores `--remote-debugging-address` and binds CDP to `127.0.0.1` only, so WSL (NAT mode) can't reach it at the Windows gateway IP. `cdp-relay.ps1` is a user-level TCP relay (`0.0.0.0:9223 → 127.0.0.1:9222`, no admin) that `start-chromium.ps1` now starts automatically; the extension connects to 9223. Verified end to end: the local model navigated to example.com and read the heading. Cold start of the extension is ~2 min (npx + Chromium launch + MCP handshake).

## This directory is the source of truth

Nothing runs from loose copies any more:

- `~/.pi/agent/settings.json` → `"extensions": ["/root/pi-mono/local/playwright-ig.ts"]` (loose copy retired to `~/.pi/agent/extensions-disabled/`).
- The extension resolves `start-chromium.ps1` next to itself and hands Windows the `\\wsl.localhost\Ubuntu\...` path via `wslpath -w`; that script starts `cdp-relay.ps1` from the same directory. The old `C:\Users\awsid\pi-ig\` copies are unused.
- `/root/start-llama.sh` and `/root/srv-sweep.sh` are symlinks into here.
- `package.json` here holds the extension's only dependency (`@modelcontextprotocol/sdk`); run `npm install` in this directory after cloning. `node_modules` is gitignored.
- `models.json` still has to be copied to `~/.pi/agent/models.json` by hand.
