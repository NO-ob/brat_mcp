# 💢 Brat MCP

A simple MCP (Model Context Protocol) server written in Dart. Exposes tools like web search and HTTP fetching over a JSON-RPC HTTP endpoint.

## Running

```bash
dart pub get
dart run bin/mcp_server.dart
```

## Arguments

| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `--port` | `-p` | `6969` | Port to listen on |
| `--ip` | `-i` | `0.0.0.0` | IP to bind to |
| `--name` | `-n` | `💢 Brat MCP` | Server name shown on startup |
| `--chrome` | `-c` | | Override for google chrome path, some paths are checked automatically |
| `--help` | `-h` | | Show usage info |

Example:
```bash
dart run bin/mcp_server.dart --port 8080 --ip 127.0.0.1
```

## Building an Executable

```bash
dart compile exe bin/mcp_server.dart -o brat_mcp
./brat_mcp --port 6969
```

## restartLlama Tool

This tool kills and restarts a local [llama.cpp](https://github.com/ggerganov/llama.cpp) server. It expects a bash script called `llama` to be available in your `$PATH`, which handles launching the server in a new GNOME terminal.

Example `llama` script (`/usr/local/bin/llama` or wherever you keep it):

```bash
#!/bin/bash
# Open llama.cpp server in a GNOME terminal
LLAMA_SERVER="/mnt/kanna/Documents/llama.cpp/build/bin/llama-server"
INI_PATH="/mnt/miku/Text/models.ini"
sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
gnome-terminal -- bash -i -c "
  echo 'Starting llama.cpp server...';
  \"$LLAMA_SERVER\" --models-preset \"$INI_PATH\" --webui-mcp-proxy
  echo;
  echo '>>> llama.cpp server exited. Use ↑ to recall and re-run.';
  exec bash -i
"
```

Make sure it's executable:
```bash
chmod +x /usr/local/bin/llama
```

When the tool is called, it waits 10 seconds, kills any running `llama-server` process (`pkill -9 llama-server`), then calls `llama` to spin it back up in a new terminal. You can trigger it by telling your AI to "kill yourself" or "kys".

## Adding Tools

Tools live in `lib/mcp_handler.dart` inside the `MCPHandler.tools` list. Adding one is straightforward — just define a name, description, properties, and an `execute` function:

```dart
MCPTool(
  name: 'myTool',
  description: 'Does something cool',
  properties: [
    MCPToolProperty(name: 'input', description: 'Some input', required: true),
  ],
  execute: (props, args) async {
    String input = args['input'];
    return MCPResponse.text('You said: $input');
  },
),
```
