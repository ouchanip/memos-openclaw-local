#!/bin/bash
# memos.sh - MemOS Memory CLI for OpenClaw agents
# Usage: memos.sh <command> [args]

MEMOS_API="${MEMOS_API_URL:-http://localhost:8000}"
MEMOS_USER="${MEMOS_USER_ID:-openclaw-user}"

case "$1" in
  remember)
    shift
    TEXT="$*"
    if [ -z "$TEXT" ]; then
      echo "Usage: memos.sh remember <text to remember>"
      exit 1
    fi
    curl -s -X POST "${MEMOS_API}/product/add" \
      -H "Content-Type: application/json" \
      -d "$(python3 -c "
import sys, json
text = sys.argv[1]
payload = {
    'user_id': '${MEMOS_USER}',
    'messages': [
        {'role': 'user', 'content': text}
    ],
    'tags': ['openclaw', 'manual'],
    'conversation_id': 'agent-explicit-' + str(__import__('time').time_ns())
}
print(json.dumps(payload, ensure_ascii=False))
" "$TEXT")" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data.get('status') == 'success' or data.get('data'):
        print('Memory saved successfully.')
    else:
        print('Response:', json.dumps(data, ensure_ascii=False, indent=2))
except Exception as e:
    print('Error parsing response:', e)
"
    ;;

  recall)
    shift
    QUERY="$*"
    if [ -z "$QUERY" ]; then
      echo "Usage: memos.sh recall <search query>"
      exit 1
    fi
    curl -s -X POST "${MEMOS_API}/product/search" \
      -H "Content-Type: application/json" \
      -d "$(python3 -c "
import sys, json
query = sys.argv[1]
payload = {
    'user_id': '${MEMOS_USER}',
    'query': query
}
print(json.dumps(payload, ensure_ascii=False))
" "$QUERY")" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    results = data.get('data', {})
    count = 0
    for mem_type in ['text_mem', 'pref_mem', 'tool_mem']:
        for cube in results.get(mem_type, []):
            for mem in cube.get('memories', []):
                count += 1
                meta = mem.get('metadata', {})
                key = meta.get('key', '')
                created = meta.get('created_at', '')
                memory = mem.get('memory', '')
                confidence = meta.get('confidence', '')
                print(f'--- Memory #{count} ---')
                if key: print(f'  Key: {key}')
                if created: print(f'  Created: {created}')
                if confidence: print(f'  Confidence: {confidence}')
                print(f'  Content: {memory[:500]}')
                print()
    if count == 0:
        print('No memories found for query:', sys.argv[1] if len(sys.argv) > 1 else '')
    else:
        print(f'Total: {count} memories found')
except Exception as e:
    print('Error:', e)
" "$QUERY"
    ;;

  remember-pair)
    shift
    USER_MSG="$1"
    ASSISTANT_MSG="$2"
    if [ -z "$USER_MSG" ] || [ -z "$ASSISTANT_MSG" ]; then
      echo "Usage: memos.sh remember-pair <user_message> <assistant_message>"
      exit 1
    fi
    curl -s -X POST "${MEMOS_API}/product/add" \
      -H "Content-Type: application/json" \
      -d "$(python3 -c "
import sys, json
user_msg = sys.argv[1]
asst_msg = sys.argv[2]
payload = {
    'user_id': '${MEMOS_USER}',
    'messages': [
        {'role': 'user', 'content': user_msg},
        {'role': 'assistant', 'content': asst_msg}
    ],
    'tags': ['openclaw', 'manual'],
    'conversation_id': 'agent-explicit-' + str(__import__('time').time_ns())
}
print(json.dumps(payload, ensure_ascii=False))
" "$USER_MSG" "$ASSISTANT_MSG")" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data.get('status') == 'success' or data.get('data'):
        print('Memory pair saved successfully.')
    else:
        print('Response:', json.dumps(data, ensure_ascii=False, indent=2))
except: pass
"
    ;;

  status)
    echo "=== MemOS API Status ==="
    curl -s "${MEMOS_API}/health" 2>/dev/null && echo "" || echo "API unreachable at ${MEMOS_API}"
    echo ""
    echo "=== Qdrant Collection ==="
    curl -s "http://localhost:6333/collections/neo4j_vec_db" 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    result = data.get('result', {})
    print(f'  Vectors: {result.get(\"vectors_count\", \"?\")}')
    print(f'  Points: {result.get(\"points_count\", \"?\")}')
except: print('  Qdrant unreachable')
" || echo "  Qdrant unreachable"
    ;;

  *)
    echo "MemOS Memory Tool - Remember and recall information"
    echo ""
    echo "Commands:"
    echo "  remember <text>                       Save a memory"
    echo "  recall <query>                        Search memories"
    echo "  remember-pair <user_msg> <asst_msg>   Save a conversation pair"
    echo "  status                                Check MemOS health"
    echo ""
    echo "Examples:"
    echo "  memos.sh remember 'User prefers Rust over Python'"
    echo "  memos.sh recall 'programming language preferences'"
    echo "  memos.sh remember-pair 'What stack?' 'User prefers Next.js + Supabase'"
    echo ""
    echo "Environment variables:"
    echo "  MEMOS_API_URL   MemOS API URL (default: http://localhost:8000)"
    echo "  MEMOS_USER_ID   MemOS user ID (default: openclaw-user)"
    ;;
esac
