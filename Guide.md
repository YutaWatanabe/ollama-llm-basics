# Ollama で LLM のテキスト生成と会話、Tool Call、Agent Loop を体験する

Claude Code や Codex などの AI コーディングエージェントが普及し、LLM の仕組みを詳しく知らなくても、AI を使ってソフトウェアを開発できるようになりました。大学生の中には、最初から Claude Code や Codex で開発を始めたという人も少なくありません。

一方で、LLM がどのようにテキストを生成し、会話を成立させ、ツールを呼び出しているのかを知らないと、AI を使えても裏側で何が起きているのかは理解しにくいままです。こうした仕組みは、一度自分の手で動かしてみるとよく分かります。

ファブリカHDでは、多くのエンジニアインターンが活躍しています。この記事では、私が普段インターンのオンボーディングで話題にしている4つのテーマを、ローカルで LLM を動かせる **Ollama** を使って確かめていきます。

| 内容 | ポイント |
|---|---|
| Text Generation | LLM はトークンを1つずつ予測している |
| Chat | 会話履歴を管理しているのはアプリ側 |
| Tool Calling | LLM はツールを実行せず、呼び出しの JSON を返すだけ |
| Agent Loop | Tool Calling の流れをループで繰り返す |

記事で使ったコマンドやコードは[リポジトリ](https://github.com/YutaWatanabe/ollama-llm-basics)にまとめています。

## 準備

[Ollama](https://ollama.com/download) をインストールします。

```bash
# macOS / Linux
curl -fsSL https://ollama.com/install.sh | sh

# Windows（PowerShell）
irm https://ollama.com/install.ps1 | iex
```

続いて API サーバーを起動します。

```bash
ollama serve
```

`http://localhost:11434` でサーバーが立ち上がります。すでに起動している場合（デスクトップアプリを開いている場合など）は不要です。

別のターミナルでモデルを取得すれば、あとは `curl` でリクエストを送るだけです。

```bash
ollama pull gemma3:1b    # テキスト生成
ollama pull qwen3:1.7b   # 会話、Tool Calling、Agent Loop
```

## テキストを生成する

`/api/generate` にプロンプトを送ります。`logprobs: true` は、生成された各トークンの文字列と、その対数確率（どれくらいの確率で選ばれたか）を返す指定です。ここではトークンの文字列だけを取り出します。

```bash
curl -s http://localhost:11434/api/generate -d '{
  "model": "gemma3:1b",
  "prompt": "こんにちは。あなたは誰ですか？一文で答えてください。",
  "stream": false,
  "logprobs": true
}' | jq -c '.response, [.logprobs[].token], {prompt_eval_count, eval_count}'
```

```
"私はGoogleによってトレーニングされた、大規模言語モデルです。"
["私は","Google","によって","トレーニング","された","、","大規模","言語","モデル","です","。"]
{"prompt_eval_count":22,"eval_count":12}
```

上から順に、生成されたテキスト、それを構成するトークン、入力・出力のトークン数です（出力は実行するたびに変わります）。LLM はテキストを **トークン** という単位で扱い、「次のトークンは何か」の予測を繰り返して文章を作っています。

トークン数には、画面に表示されない特殊なトークンも含まれるため、一覧の数とは一致しないことがあります。商用の LLM サービスでは、このトークン数が処理時間や料金に直結します。

## Chat で会話する

`/api/chat` では、会話を `messages` という配列で表します。同じ「私の名前は何ですか？」という質問を、質問だけの状態と、前の会話を追加した状態で送り比べてみます。

### 最初の状態：質問だけを送る

```bash
curl -s http://localhost:11434/api/chat -d '{
  "model": "qwen3:1.7b",
  "stream": false,
  "think": false,
  "messages": [
    { "role": "user", "content": "私の名前は何ですか？" }
  ]
}' | jq -c '.message.content, {prompt_eval_count, eval_count}'
```

```
"私の名前は「AI」です。"
{"prompt_eval_count":22,"eval_count":10}
```

名前を伝えていないので、当然答えられません（自分の名前と勘違いしています）。

### 会話を追加した状態：前のやり取りも一緒に送る

```bash
curl -s http://localhost:11434/api/chat -d '{
  "model": "qwen3:1.7b",
  "stream": false,
  "think": false,
  "messages": [
    { "role": "user", "content": "私の名前は太郎です。覚えておいてください。" },
    { "role": "assistant", "content": "わかりました。" },
    { "role": "user", "content": "私の名前は何ですか？" }
  ]
}' | jq -c '.message.content, {prompt_eval_count, eval_count}'
```

```
"太郎です。"
{"prompt_eval_count":49,"eval_count":5}
```

違いは `messages` に過去のやり取りを含めたかどうかだけです。LLM 自身はリクエストをまたいで何も記憶していません。会話を続けるには、アプリ側が履歴を管理し、必要な履歴を `messages` に含めて送ります。履歴が長くなるほど入力トークン数（`prompt_eval_count`）も増えるので、実際のアプリでは古い履歴の削除や要約も行われます。

## Tool Calling

LLM は学習済みの知識で文章を作るので、「東京の今の気温は？」には答えられません。そこで、使えるツールをリクエストの `tools` で伝えておきます。

```bash
curl -s http://localhost:11434/api/chat -d '{
  "model": "qwen3:1.7b",
  "stream": false,
  "think": false,
  "messages": [
    { "role": "user", "content": "東京の気温を調べてください。" }
  ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "指定した都市の現在の気温を取得する",
        "parameters": {
          "type": "object",
          "properties": { "city": { "type": "string" } },
          "required": ["city"]
        }
      }
    }
  ]
}' | jq '.message'
```

今回は、文章の代わりに次のメッセージが返ってきました。

```json
{
  "role": "assistant",
  "content": "",
  "tool_calls": [
    {
      "id": "call_9erztjfg",
      "function": {
        "index": 0,
        "name": "get_weather",
        "arguments": {
          "city": "東京"
        }
      }
    }
  ]
}
```

`content` は空で、代わりに `tool_calls` が入っています（`id` は呼び出しの識別子、`index` は複数の呼び出しを区別する番号です）。この時点で、LLM は天気を調べていません。返したのは「`get_weather` を `city="東京"` で呼んでほしい」という依頼だけです。ツールを実行するのは LLM の外側のプログラムです。

ここではプログラムの代わりに、ツールが `{"city": "東京", "temperature": 25, "unit": "°C"}` という JSON を返したことにします。返ってきた assistant のメッセージと、ツールの実行結果（`role: "tool"`）を `messages` に足して、もう一度送ります。

```bash
curl -s http://localhost:11434/api/chat -d '{
  "model": "qwen3:1.7b",
  "stream": false,
  "think": false,
  "messages": [
    { "role": "user", "content": "東京の気温を調べてください。" },
    {
      "role": "assistant",
      "content": "",
      "tool_calls": [
        {
          "id": "call_9erztjfg",
          "function": {
            "index": 0,
            "name": "get_weather",
            "arguments": { "city": "東京" }
          }
        }
      ]
    },
    {
      "role": "tool",
      "tool_name": "get_weather",
      "content": "{\"city\": \"東京\", \"temperature\": 25, \"unit\": \"°C\"}"
    }
  ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "指定した都市の現在の気温を取得する",
        "parameters": {
          "type": "object",
          "properties": { "city": { "type": "string" } },
          "required": ["city"]
        }
      }
    }
  ]
}' | jq -r '.message.content'
```

```
東京の現在の気温は25°Cです。
```

LLM はツールの結果を読んで回答を作りました。LLM が生成するのは「どのツールをどの引数で呼びたいか」までで、Ollama がそれを `tool_calls` として返し、実際の実行と結果の受け渡しはアプリが担います。

## 最小の Agent Loop

Tool Calling で手作業で行った流れを、Python で簡単な Agent Loop として実装してみます。

```python
session = json.load(open("03-tool-calling/session.json"))  # model、stream: false、think: false、tools
session["messages"] = [{"role": "user", "content": sys.argv[1]}]

while True:
    message = requests.post("http://localhost:11434/api/chat", json=session).json()["message"]
    session["messages"].append(message)

    if not message.get("tool_calls"):
        break

    for call in message["tool_calls"]:
        name = call["function"]["name"]
        city = call["function"]["arguments"]["city"]
        result = {"city": city, "temperature": TEMPERATURES[city], "unit": "°C"} if city in TEMPERATURES else {"city": city, "error": "not found"}
        session["messages"].append({"role": "tool", "tool_name": name, "content": json.dumps(result, ensure_ascii=False)})
```

```bash
uv run python 04-agent-loop/agent.py "東京の気温は？"
```

「東京の気温は？」と聞くと、`user` → `assistant`（Tool Call）→ `tool`（実行結果）→ `assistant`（最終回答）の順に履歴が積み上がり、手作業で作ったものと同じ形になります。「こんにちは」ならツールを使わずに1回で終わり、「大阪と東京の気温を教えて」なら、1回の返答に Tool Call が2つ入ることもあります。

学習用なので、回数制限やエラー処理は省いています。実際のエージェントでは、ツールの実行権限や回数・コストの制限が欠かせません。

## 考えてみる、掘り下げてみること

- 今回使った2つのモデル（`gemma3:1b` と `qwen3:1.7b`）の違いは何か
- Tool Calling を使うメリット、デメリットは何か
- LLM に知識や情報を与える方法は、Tool Calling のほかに何があるか
- コンテキストとは何か。いっぱいになったらどうなるか、どうすればよいか

## 終わりに

- LLM はトークンを1つずつ予測して文章を生成する
- 会話履歴はアプリが管理し、必要な履歴を毎回送っている
- Tool Calling では、LLM はツール名と引数を返すだけで、実行するのはプログラム
- Agent Loop は、Tool Call があればツールを実行し、結果を履歴に足して再び問い合わせる、の繰り返し

普段使っている AI エージェントも、LLM、会話履歴、ツール、ループが基本の構成です。製品には多くの工夫が加わっていますが、土台は今回の仕組みと同じです。

## 次のステップ

- **[MCP](https://modelcontextprotocol.io/docs/getting-started/intro)**：ツールを外部サーバーとして切り出し、どのエージェントからも使えるようにする仕組み
- **[Skills](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview)**：手順書やスクリプトを、必要なときだけコンテキストに読み込む仕組み
- **ハーネス**：[Claude Code](https://code.claude.com/docs/en/overview) や [Codex](https://developers.openai.com/codex) も、今回の Agent Loop に履歴管理や権限、MCP、Skills などの機能を足したもの

## 参考

- [Ollama API（Generate / Chat）](https://docs.ollama.com/api/chat)
- [Ollama Tool Calling](https://docs.ollama.com/capabilities/tool-calling)