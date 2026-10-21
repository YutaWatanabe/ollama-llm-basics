#!/usr/bin/env bash
# ツールを渡して Tool Call を返させる
curl -s http://localhost:11434/api/chat -d @03-tool-calling/session.json | jq '.message'
# ツールの実行結果を足して、もう一度送る
curl -s http://localhost:11434/api/chat -d @03-tool-calling/session2.json | jq -r '.message.content'
