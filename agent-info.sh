#!/bin/sh
echo "===CLAUDE==="
ls -t ~/.claude/projects/ 2>/dev/null | head -5
ps aux 2>/dev/null | grep -E "claude|codex" | grep -v grep | head -10
echo "===SESSIONS==="
find ~/.claude -name "*.jsonl" -newer /tmp -mmin -60 2>/dev/null | head -5
echo "===PROCESSES==="
ps -eo pid,comm,pcpu,pmem --sort=-pcpu | grep -iE "claude|codex|node.*claude|python.*agent" | head -10
