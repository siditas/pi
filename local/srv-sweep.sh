#!/bin/bash
# server-side sweep: real 1500-token prompt, no prompt cache, timings from llama-server log
M=/root/models/qwen3.6-35b-a3b-heretic/Qwen3.6-35B-A3B-Abliterated-Heretic-Q4_K_M/Qwen3.6-35B-A3B-Abliterated-Heretic-Q4_K_M.gguf
PROMPT=$(python3 -c "print(('The quick brown fox jumps over the lazy dog. ' * 190))")
BODY=$(python3 -c "import json,sys;print(json.dumps({'model':'x','messages':[{'role':'user','content':sys.argv[1]+' Summarize the above in 40 words.'}],'max_tokens':120,'cache_prompt':False,'chat_template_kwargs':{'enable_thinking':False}}))" "$PROMPT")
bench(){ curl -s localhost:8080/v1/chat/completions -H 'Content-Type: application/json' -d "$BODY" >/dev/null; grep -E "prompt eval time|  eval time" /root/llama-server.log | tail -2 | grep -oE "[0-9.]+ tokens per second" | tr '\n' ' '; }
start(){ pgrep -x llama-server | xargs -r kill; sleep 3; nohup /root/llama.cpp/build/bin/llama-server -m $M --alias qwen3.6-35b-a3b-heretic --host 127.0.0.1 --port 8080 -ngl 99 -c 32768 --jinja --parallel 1 --flash-attn on --temp 0.7 --top-p 0.8 --top-k 20 "$@" > /root/llama-server.log 2>&1 & for i in $(seq 1 40); do curl -sf localhost:8080/health >/dev/null && return 0; sleep 5; done; echo "FAILED TO START"; }
for cfg in "--n-cpu-moe 13 -t 8 -tb 8 --no-mmap" "--n-cpu-moe 12 -t 8 -tb 8 --no-mmap" "--n-cpu-moe 13 -t 8 -tb 8 --no-mmap"; do
  start $cfg; bench >/dev/null; echo "RESULT [$cfg] vram=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader) prompt/gen: $(bench)"
done
echo SWEEP_DONE
