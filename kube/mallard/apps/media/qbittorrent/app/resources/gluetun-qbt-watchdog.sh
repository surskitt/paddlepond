#!/bin/sh
# gluetun-qbt-watchdog
# Single script that keeps gluetun port forwarding and qBittorrent in sync.

# modified from https://github.com/brunoorsolon/gluetun-qbt-watchdog/tree/main
# thanks! :)

WATCHDOG_GLUETUN_API="${WATCHDOG_GLUETUN_API:-http://localhost:8000}"
WATCHDOG_GLUETUN_API_KEY="${WATCHDOG_GLUETUN_API_KEY:-}"
WATCHDOG_QBT_API="${WATCHDOG_QBT_API:-http://localhost:8080}"
WATCHDOG_QBT_API_KEY="${WATCHDOG_QBT_API_KEY:-}"
WATCHDOG_QBT_AUTH_MODE="${WATCHDOG_QBT_AUTH_MODE:-auto}"
WATCHDOG_QBT_USER="${WATCHDOG_QBT_USER:-admin}"
WATCHDOG_QBT_PASS="${WATCHDOG_QBT_PASS:-}"
WATCHDOG_CHECK_INTERVAL="${WATCHDOG_CHECK_INTERVAL:-60}"
WATCHDOG_PORT_MISS_THRESHOLD="${WATCHDOG_PORT_MISS_THRESHOLD:-3}"
WATCHDOG_HEARTBEAT_CYCLE_FREQUENCY="${WATCHDOG_HEARTBEAT_CYCLE_FREQUENCY:-10}"
WATCHDOG_MAX_RESTART_WAIT="${WATCHDOG_MAX_RESTART_WAIT:-120}"
WATCHDOG_QBT_COOKIE="/tmp/qbt_cookies.txt"
WATCHDOG_QBT_LOGIN_RESPONSE="/tmp/qbt_login_response.txt"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

# ---- Gluetun helpers ----
get_gluetun_port() {
    curl -sf -H "X-API-Key: $WATCHDOG_GLUETUN_API_KEY" \
        "$WATCHDOG_GLUETUN_API/v1/portforward" | grep -o '"port":[0-9]*' | grep -o '[0-9]*'
}

restart_vpn() {
    log "Restarting VPN via gluetun API..."
    curl -sf -X PUT -H "X-API-Key: $WATCHDOG_GLUETUN_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{"status":"stopped"}' \
        "$WATCHDOG_GLUETUN_API/v1/vpn/status" >/dev/null
    sleep 5
    curl -sf -X PUT -H "X-API-Key: $WATCHDOG_GLUETUN_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{"status":"running"}' \
        "$WATCHDOG_GLUETUN_API/v1/vpn/status" >/dev/null
}

# ---- qBittorrent helpers ----
validate_qbt_auth_mode() {
    case "$WATCHDOG_QBT_AUTH_MODE" in
    auto | apikey | password) return 0 ;;
    *)
        log "ERROR: Invalid WATCHDOG_QBT_AUTH_MODE '$WATCHDOG_QBT_AUTH_MODE'. Use auto, apikey, or password."
        return 1
        ;;
    esac
}

qbt_uses_api_key() {
    [ "$WATCHDOG_QBT_AUTH_MODE" = "apikey" ] ||
        { [ "$WATCHDOG_QBT_AUTH_MODE" = "auto" ] && [ -n "$WATCHDOG_QBT_API_KEY" ]; }
}

qbt_auth_description() {
    if qbt_uses_api_key; then
        echo "api key"
    else
        echo "username/password"
    fi
}

qbt_curl() {
    if qbt_uses_api_key; then
        curl -sf -H "Authorization: Bearer $WATCHDOG_QBT_API_KEY" "$@"
    else
        curl -sf -b "$WATCHDOG_QBT_COOKIE" "$@"
    fi
}

qbt_check_api_key() {
    if [ -z "$WATCHDOG_QBT_API_KEY" ]; then
        log "ERROR: WATCHDOG_QBT_AUTH_MODE=apikey requires WATCHDOG_QBT_API_KEY."
        return 1
    fi

    local status
    status=$(curl -s -o /dev/null -w '%{http_code}' \
        -H "Authorization: Bearer $WATCHDOG_QBT_API_KEY" \
        "$WATCHDOG_QBT_API/api/v2/app/webapiVersion")

    case "$status" in
    200) return 0 ;;
    401 | 403) log "ERROR: qBittorrent API key was rejected." ;;
    404) log "ERROR: qBittorrent WebAPI endpoint not found; API-key auth requires qBittorrent 5.2.0 / WebAPI 2.14.1+." ;;
    000) log "WARNING: qBittorrent WebAPI is unreachable." ;;
    *) log "ERROR: qBittorrent API-key probe failed with HTTP $status." ;;
    esac
    return 1
}

# Login helper that can try either the configured password or a temporary one recovered from logs.
qbt_login_with_password() {
    local password="$1"
    local status
    local result

    status=$(curl -s -o "$WATCHDOG_QBT_LOGIN_RESPONSE" -w '%{http_code}' -c "$WATCHDOG_QBT_COOKIE" \
        --data-urlencode "username=$WATCHDOG_QBT_USER" --data-urlencode "password=$password" \
        "$WATCHDOG_QBT_API/api/v2/auth/login")
    result=$(tr -d '\r' <"$WATCHDOG_QBT_LOGIN_RESPONSE")

    if [ "$status" = "204" ]; then
        return 0
    fi

    if [ "$status" = "200" ] && [ "$result" = "Ok." ]; then
        return 0
    fi

    case "$status" in
    401) log "ERROR: qBittorrent login failed: invalid credentials." ;;
    000) log "WARNING: qBittorrent WebAPI is unreachable." ;;
    *) log "ERROR: qBittorrent login failed with HTTP $status." ;;
    esac
    return 1
}

qbt_login() {
    qbt_login_with_password "$WATCHDOG_QBT_PASS"
}

qbt_authenticate() {
    if qbt_uses_api_key; then
        qbt_check_api_key
        return $?
    fi

    if qbt_login; then
        return 0
    fi
}

get_qbt_port() {
    qbt_curl "$WATCHDOG_QBT_API/api/v2/app/preferences" |
        grep -o '"listen_port"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*'
}

set_qbt_port() {
    qbt_curl \
        --data-urlencode "json={\"listen_port\":$1,\"random_port\":false,\"upnp\":false}" \
        "$WATCHDOG_QBT_API/api/v2/app/setPreferences" >/dev/null
}

# Updates the Web UI password to the configured WATCHDOG_QBT_PASS value.
set_qbt_password() {
    local escaped_password
    escaped_password=$(printf '%s' "$WATCHDOG_QBT_PASS" | sed 's/\\/\\\\/g; s/"/\\"/g')
    curl -sf -b "$WATCHDOG_QBT_COOKIE" \
        --data-urlencode "json={\"web_ui_password\":\"$escaped_password\"}" \
        "$WATCHDOG_QBT_API/api/v2/app/setPreferences" >/dev/null
}

wait_for_port() {
    local waited=0
    while [ $waited -lt "$WATCHDOG_MAX_RESTART_WAIT" ]; do
        local port
        port=$(get_gluetun_port)
        if [ -n "$port" ] && [ "$port" != "0" ]; then
            echo "$port"
            return 0
        fi
        sleep 10
        waited=$((waited + 10))
    done
    return 1
}

# ---- Main loop ----
log "Watchdog started. Checking every ${WATCHDOG_CHECK_INTERVAL}s, heartbeat every ${WATCHDOG_HEARTBEAT_CYCLE_FREQUENCY} cycles"
log "Gluetun API: $WATCHDOG_GLUETUN_API"
log "qBittorrent API: $WATCHDOG_QBT_API"
if ! validate_qbt_auth_mode; then
    exit 1
fi
log "qBittorrent auth mode: $(qbt_auth_description)"

# Initial delay to let everything start up
sleep 30

cycle_count=0
port_miss_count=0

while true; do
    cycle_count=$((cycle_count + 1))

    # Step 1: Get gluetun's forwarded port
    gluetun_port=$(get_gluetun_port)

    if [ -z "$gluetun_port" ] || [ "$gluetun_port" = "0" ]; then
        port_miss_count=$((port_miss_count + 1))
        if [ "$port_miss_count" -lt "$WATCHDOG_PORT_MISS_THRESHOLD" ]; then
            log "WARNING: No forwarded port from gluetun ($port_miss_count/$WATCHDOG_PORT_MISS_THRESHOLD), waiting for gluetun to retry"
            sleep "$WATCHDOG_CHECK_INTERVAL"
            continue
        fi
        log "WARNING: No forwarded port from gluetun. Attempting VPN restart..."
        restart_vpn
        port_miss_count=0
        sleep 15
        gluetun_port=$(get_gluetun_port)

        if [ -z "$gluetun_port" ] || [ "$gluetun_port" = "0" ]; then
            log "ERROR: VPN restart didn't help."
            sleep "$WATCHDOG_CHECK_INTERVAL"
            continue
        fi
        log "New port after recovery: $gluetun_port"
    fi

    port_miss_count=0

    # Step 2: Authenticate to qBittorrent
    if ! qbt_authenticate; then
        log "WARNING: Can't authenticate to qBittorrent. Skipping this cycle."
        sleep "$WATCHDOG_CHECK_INTERVAL"
        continue
    fi

    # Step 3: Check if qBittorrent has the right port
    qbt_port=$(get_qbt_port)

    if [ -z "$qbt_port" ]; then
        log "WARNING: Can't read qBittorrent preferences. Skipping this cycle."
        sleep "$WATCHDOG_CHECK_INTERVAL"
        continue
    fi

    if [ "$qbt_port" != "$gluetun_port" ]; then
        log "WARNING: Port mismatch: gluetun=$gluetun_port, qbt=$qbt_port. Fixing..."
        set_qbt_port "$gluetun_port"
        sleep 2
        qbt_port=$(get_qbt_port)
        if [ "$qbt_port" = "$gluetun_port" ]; then
            log "Port synced successfully: $gluetun_port"
        else
            log "ERROR: Failed to set port. qbt still reports $qbt_port"
        fi
    elif [ $((cycle_count % WATCHDOG_HEARTBEAT_CYCLE_FREQUENCY)) -eq 0 ]; then
        log "OK: gluetun=$gluetun_port, qbt=$qbt_port"
    fi

    sleep "$WATCHDOG_CHECK_INTERVAL"
done
