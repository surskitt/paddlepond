#!/usr/bin/env dash

echo "=== Running navidrome wait script"
/scripts/navidrome_wait.py

echo "=== Running queue to playlist sync"
/scripts/navidrome_queue_to_playlist.py

echo "=== Running sorted cache script"
/scripts/navidrome_cache_sorted.py

echo "=== Waiting 5 minutes until next run"

while sleep 300; do
    echo "=== Running queue to playlist sync"
    /scripts/navidrome_queue_to_playlist.py

    echo "=== Running sorted cache script"
    /scripts/navidrome_cache_sorted.py

    echo "=== Waiting 5 minutes until next run"
done
