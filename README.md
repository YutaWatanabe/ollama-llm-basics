# ollama-starter

Ollama と `curl` で、LLM の仕組み（テキスト生成・会話履歴・Tool Calling・Agent Loop）を体験するためのコード置き場です。解説は [Guide.md](Guide.md) にあります。

## 必要なもの

- [Ollama](https://ollama.com/)
- `curl`、[`jq`](https://jqlang.org/)
- [uv](https://docs.astral.sh/uv/)（Agent Loop のみ）

```bash
ollama pull gemma3:1b
ollama pull qwen3:1.7b
```

## 構成

| ディレクトリ | 内容 |
|---|---|
| `01-generate/` | テキスト生成とトークン |
| `02-chat/` | 会話履歴（質問だけ / 前の会話を追加） |
| `03-tool-calling/` | Tool Call を返させる / ツールの結果を足して送り直す |
| `04-agent-loop/` | 最小の Agent Loop |

## 使い方

リポジトリのルートで実行します。各スクリプトは [Guide.md](Guide.md) のコマンドと同じものです。

```bash
./01-generate/generate.sh
./02-chat/chat.sh
./03-tool-calling/tool-call.sh
./04-agent-loop/run.sh
```
