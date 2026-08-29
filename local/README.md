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
