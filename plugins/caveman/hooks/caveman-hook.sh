#!/usr/bin/env bash
# UserPromptSubmit hook: keep /tmp/claude-caveman-<session> in sync with the
# caveman level the user requests in their prompt, so a statusline can show it.
set -euo pipefail

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""')
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // ""' | tr '[:upper:]' '[:lower:]')

[[ -z "$SESSION_ID" ]] && exit 0

FLAG="/tmp/claude-caveman-${SESSION_ID}"

# Only react when the prompt actually mentions caveman / normal mode.
if [[ "$PROMPT" == *"stop caveman"* || "$PROMPT" == *"normal mode"* ]]; then
    rm -f "$FLAG"
elif [[ "$PROMPT" == *caveman* ]]; then
    if [[ "$PROMPT" == *ultra* ]]; then
        printf 'ultra' > "$FLAG"
    elif [[ "$PROMPT" == *lite* ]]; then
        printf 'lite' > "$FLAG"
    elif [[ "$PROMPT" == *full* ]]; then
        printf 'full' > "$FLAG"
    else
        printf 'full' > "$FLAG"   # bare "caveman" = default level
    fi
fi

exit 0

