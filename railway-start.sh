#!/bin/sh
# Railway start script for the Nezha dashboard.
# 1. On first boot, replace the seeded admin/admin login with ADMIN_PASSWORD
#    (the dashboard only listens on 127.0.0.1 while it does this).
# 2. Start the dashboard on $PORT, with the agent address set to Railway's TCP proxy.
# 3. Exit non-zero if the dashboard stops on its own, so Railway restarts it.
set -u

DATA=/dashboard/data
CONF="$DATA/config.yaml"
DB="$DATA/sqlite.db"
MARK="$DATA/.railway-admin-initialised"
PORT="${PORT:-8008}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"

log() { echo "railway-start: $*"; }
die() { log "ERROR: $*"; exit 1; }

mkdir -p "$DATA" || die "cannot create $DATA (is the volume mounted?)"

json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

# POST JSON to the bootstrap instance. Usage: post <path> <body> [extra wget args...]
BOOT_PORT=18008
BOOT_URL="http://127.0.0.1:$BOOT_PORT"
post() {
  _p="$1"; _b="$2"; shift 2
  wget -q -S -O "$BOOT_TMP/body" --header 'Content-Type: application/json' "$@" \
    --post-data "$_b" "$BOOT_URL$_p" 2>"$BOOT_TMP/headers"
}

init_admin() {
  [ -n "$ADMIN_PASSWORD" ] || die "ADMIN_PASSWORD is empty; set it in the service variables"
  _len=$(printf '%s' "$ADMIN_PASSWORD" | wc -c)
  if [ "$_len" -lt 8 ] || [ "$_len" -gt 72 ]; then
    die "ADMIN_PASSWORD must be 8 to 72 bytes long"
  fi
  BOOT_TMP=$(mktemp -d)
  mkdir -p "$BOOT_TMP/conf"
  log "first boot: starting the dashboard on 127.0.0.1 to set the admin login"
  NZ_LISTENHOST=127.0.0.1 NZ_LISTENPORT=$BOOT_PORT \
    /dashboard/app -c "$BOOT_TMP/conf/config.yaml" -db "$DB" >"$BOOT_TMP/app.log" 2>&1 &
  _pid=$!
  _i=0
  until wget -q -O /dev/null "$BOOT_URL/api/v1/setting" 2>/dev/null; do
    _i=$((_i + 1))
    if ! kill -0 "$_pid" 2>/dev/null; then cat "$BOOT_TMP/app.log"; die "dashboard exited during first boot"; fi
    [ "$_i" -lt 120 ] || { kill "$_pid"; die "dashboard did not answer within 120 s during first boot"; }
    sleep 1
  done

  _ok=0
  post /api/v1/login '{"username":"admin","password":"admin"}'
  if grep -q '"success":true' "$BOOT_TMP/body" 2>/dev/null; then
    _token=$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$BOOT_TMP/body")
    _csrf=$(sed -n 's/.*[Ss]et-[Cc]ookie: nz-csrf=\([^;]*\).*/\1/p' "$BOOT_TMP/headers" | head -n 1)
    [ -n "$_token" ] && [ -n "$_csrf" ] || { kill "$_pid"; die "login answered without a token or CSRF cookie"; }
    _body="{\"original_password\":\"admin\",\"new_username\":\"$(json_escape "$ADMIN_USERNAME")\",\"new_password\":\"$(json_escape "$ADMIN_PASSWORD")\"}"
    if post /api/v1/profile "$_body" --header "Authorization: Bearer $_token" \
         --header "Cookie: nz-csrf=$_csrf" --header "X-CSRF-Token: $_csrf" \
       && grep -q '"success":true' "$BOOT_TMP/body"; then
      log "admin login set (username: $ADMIN_USERNAME)"
      _ok=1
    else
      cat "$BOOT_TMP/body" 2>/dev/null; echo
      kill "$_pid"; die "could not change the default admin password"
    fi
  else
    # admin/admin no longer works: the password was already changed earlier.
    log "default admin/admin login is not active; leaving the existing admin as it is"
    _ok=1
  fi
  kill "$_pid" 2>/dev/null
  wait "$_pid" 2>/dev/null
  rm -r "$BOOT_TMP"
  [ "$_ok" = 1 ] && : >"$MARK"
}

[ -f "$MARK" ] || init_admin

# Settings from the environment apply only while config.yaml doesn't hold them yet
# (the first start writes them there; later changes in the admin UI win).
export NZ_LISTENPORT="$PORT"
export NZ_LOCATION="${NZ_LOCATION:-UTC}"
if [ -n "${RAILWAY_TCP_PROXY_DOMAIN:-}" ] && [ -n "${RAILWAY_TCP_PROXY_PORT:-}" ]; then
  export NZ_INSTALLHOST="${NZ_INSTALLHOST:-$RAILWAY_TCP_PROXY_DOMAIN:$RAILWAY_TCP_PROXY_PORT}"
fi
# Railway routes the domain to $PORT, so keep the saved listen port in step with it.
if [ -f "$CONF" ]; then
  if grep -q '^listen_port:' "$CONF"; then
    sed -i "s/^listen_port:.*/listen_port: $PORT/" "$CONF"
  else
    echo "listen_port: $PORT" >>"$CONF"
  fi
  sed -i '/^listen_host:/d' "$CONF"
fi

log "starting the Nezha dashboard on port $PORT"
/dashboard/app &
APP=$!
trap 'kill -TERM "$APP" 2>/dev/null; wait "$APP"; exit 0' TERM INT
wait "$APP"
RC=$?
log "dashboard stopped on its own (exit $RC); exiting non-zero so Railway restarts it"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
