import json
import sys

import requests

TEMPERATURES = {"東京": 25, "大阪": 28, "札幌": 18, "福岡": 27, "那覇": 31}

session = json.load(open("03-tool-calling/session.json"))
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

print(json.dumps(session["messages"], ensure_ascii=False, indent=2))
