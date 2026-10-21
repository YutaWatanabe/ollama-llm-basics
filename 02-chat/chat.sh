#!/usr/bin/env bash
# 最初の状態：質問だけを送る
curl -s http://localhost:11434/api/chat -d @02-chat/session1.json | jq -c '.message.content, {prompt_eval_count, eval_count}'
# 会話を追加した状態：前のやり取りも一緒に送る
curl -s http://localhost:11434/api/chat -d @02-chat/session2.json | jq -c '.message.content, {prompt_eval_count, eval_count}'
