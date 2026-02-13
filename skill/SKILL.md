---
name: memos-memory
description: Remember and recall information using MemOS long-term memory. Use when you want to explicitly save important facts, user preferences, or project context, or when you need to search past memories.
---

# MemOS Memory

Agent skill for actively remembering and recalling information.
Works alongside the lifecycle plugin (auto-capture) for hybrid memory.

## Quick Reference

Use the bundled script `scripts/memos.sh` for all operations:

```bash
# Remember important information
./scripts/memos.sh remember "User prefers TypeScript over JavaScript"

# Search past memories
./scripts/memos.sh recall "programming language preferences"

# Save as conversation pair (richer context)
./scripts/memos.sh remember-pair "What framework do you use?" "User prefers Next.js + Supabase"

# Check MemOS status
./scripts/memos.sh status
```

## When to Use

### remember
Actively save important information when you discover:
- **User preferences**: Tech choices, coding style, language settings
- **Project info**: Architecture decisions, tech stack, config values
- **Problems & solutions**: Bugs found, workarounds, debugging hints
- **Decisions**: Technical judgments and policies made by the user

### recall
Search past memories when:
- You want to check user preferences before starting a task
- You want to see if a similar problem was solved before
- You need background context about the project

## Architecture

| Component | Role |
|---|---|
| MemOS API (localhost:8002) | Memory management server |
| Neo4j (localhost:7687) | Graph DB (relationships) |
| Qdrant (localhost:6333) | Vector DB (semantic search) |
| Ollama (localhost:11434) | Embedding + LLM |

## Tag Convention

| Tag | Meaning |
|---|---|
| openclaw, auto | Auto-captured by lifecycle plugin |
| openclaw, manual | Explicitly saved by this skill |

## Notes

- Auto-capture (lifecycle) records full conversations as a safety net
- This skill is for selectively saving important information
- MemOS internally handles dedup, merge, and hierarchical organization — save freely without worrying about duplicates
- Search uses hybrid: vector similarity + BM25 + graph traversal
