#!/bin/sh
# Install ffmpeg if not present
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Installing ffmpeg..."
    apk update && apk add --no-cache ffmpeg
fi

# Call original entrypoint
exec /entrypoint.sh "$@"
