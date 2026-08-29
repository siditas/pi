#!/bin/bash
exec /root/llama.cpp/build/bin/llama-server \
  -m /root/models/qwen3.6-35b-a3b-heretic/Qwen3.6-35B-A3B-Abliterated-Heretic-Q4_K_M/Qwen3.6-35B-A3B-Abliterated-Heretic-Q4_K_M.gguf \
  --alias qwen3.6-35b-a3b-heretic --host 127.0.0.1 --port 8080 \
  -ngl 99 --n-cpu-moe 12 --no-mmap -c 32768 --jinja --parallel 1 --flash-attn on \
  -t 8 -tb 8 --temp 0.7 --top-p 0.8 --top-k 20 "$@"
