# MemOS + OpenClaw Local Integration

> **This is a community fork of the official [MemOS-Cloud-OpenClaw-Plugin](https://github.com/MemTensor/MemOS-Cloud-OpenClaw-Plugin) by [MemTensor](https://github.com/MemTensor), adapted for self-hosted MemOS instances.**
> The original plugin works with [MemOS Cloud](https://www.memos.co/) — a managed service with authentication, dashboard, and zero setup.
> This fork modifies API paths and response adapters to work with the self-hosted [MemOS](https://github.com/MemTensor/MemOS) API.

## Cloud vs Self-Hosted — Which Should You Use?

| | [MemOS Cloud (Official Plugin)](https://github.com/MemTensor/MemOS-Cloud-OpenClaw-Plugin) | Self-Hosted (This Fork) |
|---|---|---|
| **Setup** | Sign up and get an API key — done | Deploy MemOS + Qdrant + Neo4j + Ollama yourself |
| **Maintenance** | Zero — managed by MemTensor | You manage updates, backups, infra |
| **Data location** | MemOS Cloud servers | Your own machine — 100% local |
| **Cost** | Cloud plan pricing | Free (your hardware + electricity) |
| **Best for** | Quick start, production use, teams | Privacy-first, air-gapped environments, tinkerers |

**If you just want long-term memory for your agents, start with the [official Cloud plugin](https://github.com/MemTensor/MemOS-Cloud-OpenClaw-Plugin).** It's simpler, maintained by the MemOS team, and works out of the box. This fork exists for users who need to keep all data on their own infrastructure.

## What This Is

A fork of the official OpenClaw plugin, adapted for self-hosted MemOS. It gives your AI agent **long-term memory** using a local MemOS instance. Conversations are automatically stored and recalled across sessions.

**Hybrid Memory Design:**

| Component | Strategy | When |
|---|---|---|
| Lifecycle Plugin | Auto-capture full sessions | Every conversation end |
| Agent Skill | Manual remember/recall | Agent explicitly saves important facts |

## Architecture

```
OpenClaw Agent
  ├── [before_agent_start] → MemOS /product/search → recall relevant memories
  └── [agent_end]          → MemOS /product/add    → store conversation
                                    ↓
                              MemOS API (:8000)
                              ├── Qdrant (:6333) — vector search
                              ├── Neo4j  (:7687) — graph DB
                              └── Ollama (:11434) — embedding + LLM
```

## Prerequisites

- [OpenClaw](https://github.com/openclaw/openclaw) installed
- [Docker](https://docs.docker.com/get-docker/) and Docker Compose
- [Neo4j Community](https://neo4j.com/download/) running on port 7687
- [Ollama](https://ollama.ai/) running on port 11434 with:
  - An embedding model (default: `qwen3-embedding:0.6b`)
  - A chat model (default: `gemma3:4b`)

## Quick Start

### 1. Clone and configure

```bash
git clone https://github.com/YOUR_USER/memos-openclaw-local.git
cd memos-openclaw-local

# Copy and edit environment variables
cp .env.example .env
# Edit .env — set your Neo4j password, Ollama host, models, etc.
```

### 2. Pull required Ollama models

```bash
ollama pull qwen3-embedding:0.6b
ollama pull gemma3:4b
```

### 3. Clone MemOS and apply patches

```bash
# Clone MemOS source (required for Docker build)
git clone https://github.com/MemTensor/MemOS.git

# Copy our docker-compose and env into MemOS
cp docker/docker-compose.override.yml MemOS/docker/
cp .env MemOS/

# Apply the Neo4j Community search patch
# See patches/searcher.py.patch for details
# Edit: MemOS/src/memos/memories/textual/tree_text_memory/retrieve/searcher.py
```

**Patch 1** — Add at the top of `_retrieve_from_keyword` method:
```python
if not hasattr(self.graph_store, 'search_by_fulltext'):
    return []
```

**Patch 2** — In `_retrieve_paths`, wrap result collection with try/except:
```python
results = []
for t in tasks:
    try:
        results.extend(t.result())
    except Exception as e:
        logger.warning(f"[SEARCH] Search path failed: {e}")
```

### 4. Start MemOS

```bash
cd MemOS/docker
docker compose -f docker-compose.override.yml up -d
```

Verify it's running:
```bash
curl http://localhost:8000/health
```

### 5. Install the OpenClaw plugin

```bash
# Copy plugin to a permanent location
cp -r plugin /path/to/memos-local-openclaw-plugin

# Add to your OpenClaw config (~/.openclaw/openclaw.json):
```

```json
{
  "plugins": {
    "entries": {
      "memos-local-openclaw-plugin": {
        "enabled": true,
        "config": {
          "baseUrl": "http://localhost:8000",
          "userId": "openclaw-user",
          "recallEnabled": true,
          "addEnabled": true,
          "captureStrategy": "full_session",
          "includeAssistant": true,
          "memoryLimitNumber": 6,
          "tags": ["openclaw", "auto"]
        }
      }
    },
    "load": {
      "paths": ["/path/to/memos-local-openclaw-plugin"]
    }
  }
}
```

### 6. (Optional) Install the agent skill

```bash
# Copy skill to OpenClaw skills directory
cp -r skill ~/.openclaw/skills/memos-memory
```

The agent can then use `remember`, `recall`, and `status` commands.

## Configuration

### Key .env Variables

| Variable | Default | Description |
|---|---|---|
| `MOS_CHAT_MODEL` | `gemma3:4b` | LLM for memory processing |
| `MOS_EMBEDDER_MODEL` | `qwen3-embedding:0.6b` | Embedding model |
| `EMBEDDING_DIMENSION` | `1024` | Must match your embedding model's output |
| `NEO4J_PASSWORD` | — | Your Neo4j password |
| `OLLAMA_API_BASE` | `http://host.docker.internal:11434` | Ollama endpoint (from inside Docker) |

### Plugin Config Options

| Option | Default | Description |
|---|---|---|
| `baseUrl` | `http://localhost:8000` | MemOS API URL |
| `userId` | `openclaw-user` | MemOS user identifier |
| `captureStrategy` | `last_turn` | `last_turn` or `full_session` |
| `includeAssistant` | `true` | Include assistant responses in memory |
| `memoryLimitNumber` | `6` | Max memories to recall per query |
| `tags` | `["openclaw"]` | Tags for stored memories |
| `recallEnabled` | `true` | Enable memory recall on agent start |
| `addEnabled` | `true` | Enable memory capture on agent end |

## Docker Management

```bash
cd MemOS/docker

# Start
docker compose -f docker-compose.override.yml up -d

# Stop
docker compose -f docker-compose.override.yml down

# Logs
docker logs memos-api --tail 30

# IMPORTANT: Always use down+up to restart (not 'restart')
# 'docker compose restart' does NOT reload .env changes
```

## Known Issues

1. **MemOS delete API bug**: `delete_node_by_prams()` has a missing argument. Delete memories directly via Neo4j + Qdrant.
2. **docker compose restart ignores .env**: Always use `down` then `up` to apply config changes.
3. **Embedding dimension mismatch**: If you change embedding models, delete the Qdrant collection and restart.
4. **WatchFiles hot-reload**: Can corrupt singleton state. Always do a full `down+up` after editing MemOS source files.

## Credits

This project is a fork of [MemOS-Cloud-OpenClaw-Plugin](https://github.com/MemTensor/MemOS-Cloud-OpenClaw-Plugin) by [MemTensor](https://github.com/MemTensor). All core plugin logic (lifecycle hooks, prompt injection, memory formatting) comes from the original. This fork only modifies the API layer (paths, authentication, response adapters) to work with self-hosted MemOS.

- [MemOS](https://github.com/MemTensor/MemOS) — The Memory Operating System
- [MemOS Cloud](https://www.memos.co/) — Managed MemOS service
- [MemOS-Cloud-OpenClaw-Plugin](https://github.com/MemTensor/MemOS-Cloud-OpenClaw-Plugin) — The original official plugin

## License

Apache-2.0 — Same as [MemOS](https://github.com/MemTensor/MemOS) and the [original OpenClaw plugin](https://github.com/MemTensor/MemOS-Cloud-OpenClaw-Plugin).
