#!/usr/bin/env bash
curl -s http://localhost:11434/api/generate -d '{
  "model": "gemma3:1b",
  "prompt": "こんにちは。あなたは誰ですか？一文で答えてください。",
  "stream": false,
  "logprobs": true
}' | jq -c '.response, [.logprobs[].token], {prompt_eval_count, eval_count}'
