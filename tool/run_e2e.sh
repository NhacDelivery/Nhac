#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${RUN_E2E:-}" != "true" ]]; then
  echo "RUN_E2E=true é obrigatório." >&2
  exit 2
fi

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="${BACKEND_DIR:-$(cd "$APP_DIR/../backend-nhac" && pwd)}"
BACKEND_JAR="${BACKEND_JAR:-$BACKEND_DIR/target/backend_nhac-0.0.1-SNAPSHOT.jar}"
BACKEND_JAVA_HOME="${BACKEND_JAVA_HOME:-${JAVA_HOME:-}}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
DEVICE_ID="${E2E_DEVICE_ID:-emulator-5554}"
APP_ID="${E2E_APP_ID:-com.feentzs.nhac}"
REPEAT="${E2E_REPEAT:-1}"
ONLY="${E2E_ONLY:-all}"
DB_PORT="${E2E_DB_PORT:-3307}"
BACKEND_PORT="${E2E_BACKEND_PORT:-8080}"
LOG_DIR="${E2E_LOG_DIR:-$APP_DIR/e2e-logs}"
DB_CONTAINER="nhac-e2e-db-${GITHUB_RUN_ID:-local}-$$"
BACKEND_PID=""
LAST_TEST="startup"

if ! [[ "$REPEAT" =~ ^[1-9][0-9]*$ ]] || [[ "$REPEAT" -gt 20 ]]; then
  echo "E2E_REPEAT deve ser um inteiro entre 1 e 20." >&2
  exit 2
fi
if [[ "$ONLY" != all && "$ONLY" != login && "$ONLY" != order_cash ]]; then
  echo "E2E_ONLY aceita login ou order_cash." >&2
  exit 2
fi
if [[ -z "$BACKEND_JAVA_HOME" || ! -x "$BACKEND_JAVA_HOME/bin/java" || ! -f "$BACKEND_JAR" ]]; then
  echo "Build do backend ou JDK ausente. Execute ./mvnw -B -ntp -DskipTests package com Java 25." >&2
  exit 2
fi
if [[ ! -f "$APP_DIR/.env" ]]; then
  echo "Arquivo .env E2E ausente." >&2
  exit 2
fi
mapfile -t api_lines < <(sed -n 's/^API_BASE_URL=//p' "$APP_DIR/.env")
if [[ "${#api_lines[@]}" -ne 1 ]] || ! grep -Fxq 'E2E_MODE=true' "$APP_DIR/.env"; then
  echo "O .env E2E precisa ter uma única API_BASE_URL e E2E_MODE=true." >&2
  exit 2
fi
API_BASE_URL="${api_lines[0]}"
if ! [[ "$API_BASE_URL" =~ ^http://(10\.0\.2\.2|127\.0\.0\.1|localhost):([0-9]+)/api/v1/?$ ]] ||
   [[ "${BASH_REMATCH[2]:-}" != "$BACKEND_PORT" ]]; then
  echo "API E2E recusada: use somente o backend isolado local na porta $BACKEND_PORT." >&2
  exit 2
fi

mkdir -p "$LOG_DIR"
cd "$APP_DIR"

port_busy() { (exec 3<>/dev/tcp/127.0.0.1/"$BACKEND_PORT") 2>/dev/null; }

stop_backend() {
  if [[ -n "$BACKEND_PID" ]] && kill -0 "$BACKEND_PID" 2>/dev/null; then
    kill "$BACKEND_PID" 2>/dev/null || true
    for _ in $(seq 1 30); do
      kill -0 "$BACKEND_PID" 2>/dev/null || break
      sleep 0.5
    done
    if kill -0 "$BACKEND_PID" 2>/dev/null; then
      kill -KILL "$BACKEND_PID" 2>/dev/null || true
    fi
    wait "$BACKEND_PID" 2>/dev/null || true
  fi
  BACKEND_PID=""
}

capture_failure() {
  local prefix="$1"
  adb -s "$DEVICE_ID" logcat -d >"$LOG_DIR/$prefix.logcat.txt" 2>/dev/null || true
  adb -s "$DEVICE_ID" exec-out screencap -p >"$LOG_DIR/$prefix.png" 2>/dev/null || true
  if [[ -n "${E2E_DB_CONTAINER:-}" ]]; then
    docker logs "$E2E_DB_CONTAINER" >"$LOG_DIR/$prefix.mariadb.log" 2>&1 || true
  elif [[ "${E2E_DB_MANAGED:-false}" != "true" ]]; then
    docker logs "$DB_CONTAINER" >"$LOG_DIR/$prefix.mariadb.log" 2>&1 || true
  fi
}

on_exit() {
  local status="$1"
  trap - EXIT
  if (( status != 0 )); then capture_failure "final-$LAST_TEST"; fi
  stop_backend
  if [[ "${E2E_DB_MANAGED:-false}" != "true" ]]; then
    docker rm -f "$DB_CONTAINER" >/dev/null 2>&1 || true
  fi
  exit "$status"
}
trap 'on_exit $?' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if port_busy; then
  echo "Porta $BACKEND_PORT ocupada antes do início; não vou usar um backend existente." >&2
  exit 1
fi

echo '::group::Versões E2E'
"$BACKEND_JAVA_HOME/bin/java" -version
"$FLUTTER_BIN" --version
adb -s "$DEVICE_ID" shell getprop ro.build.version.sdk
echo '::endgroup::'

if [[ "${E2E_DB_MANAGED:-false}" != "true" ]]; then
  echo '::group::MariaDB E2E'
  docker run --detach --rm \
    --name "$DB_CONTAINER" --publish "${DB_PORT}:3306" \
    --env MARIADB_DATABASE=nhac_e2e \
    --env MARIADB_USER=nhac_e2e \
    --env MARIADB_PASSWORD=nhac_e2e \
    --env MARIADB_ROOT_PASSWORD=nhac_e2e_root \
    --health-cmd='healthcheck.sh --connect --innodb_initialized' \
    --health-interval=2s --health-timeout=2s --health-retries=30 \
    mariadb:11.4 >/dev/null
  db_deadline=$((SECONDS + 60))
  while (( SECONDS < db_deadline )); do
    [[ "$(docker inspect --format '{{.State.Health.Status}}' "$DB_CONTAINER")" == healthy ]] && break
    sleep 1
  done
  if [[ "$(docker inspect --format '{{.State.Health.Status}}' "$DB_CONTAINER")" != healthy ]]; then
    echo "MariaDB E2E não ficou saudável." >&2
    exit 1
  fi
  echo '::endgroup::'
fi

start_backend() {
  local label="$1" body backend_log="$LOG_DIR/backend-$1.log"
  if port_busy; then
    echo "Porta $BACKEND_PORT ocupada antes de $label; execução interrompida." >&2
    return 1
  fi
  (
    cd "$BACKEND_DIR"
    export E2E_DB_URL="jdbc:mariadb://127.0.0.1:${DB_PORT}/nhac_e2e?serverTimezone=UTC&rewriteBatchedStatements=true"
    export E2E_DB_USER=nhac_e2e E2E_DB_PASSWORD=nhac_e2e SERVER_PORT="$BACKEND_PORT"
    exec "$BACKEND_JAVA_HOME/bin/java" -XX:TieredStopAtLevel=1 -jar "$BACKEND_JAR" --spring.profiles.active=e2e
  ) >"$backend_log" 2>&1 &
  BACKEND_PID=$!

  local deadline=$((SECONDS + 120))
  while (( SECONDS < deadline )); do
    if body=$(curl -fsS --max-time 2 "http://127.0.0.1:${BACKEND_PORT}/actuator/health" 2>/dev/null) &&
       [[ "$body" == *'"status":"UP"'* ]]; then
      return 0
    fi
    kill -0 "$BACKEND_PID" 2>/dev/null || break
    sleep 1
  done
  tail -n 200 "$backend_log" >&2 || true
  echo "Backend E2E não ficou saudável em $label." >&2
  return 1
}

declare -A passed=([login]=0 [order_cash]=0)
declare -A failed=([login]=0 [order_cash]=0)
declare -A retried=([login]=0 [order_cash]=0)
declare -A elapsed=([login]=0 [order_cash]=0)
DEFINES=(--dart-define=RUN_E2E=true)
tests=()
[[ "$ONLY" == all || "$ONLY" == login ]] && tests+=(login)
[[ "$ONLY" == all || "$ONLY" == order_cash ]] && tests+=(order_cash)
attempts=2
if (( REPEAT > 1 )); then attempts=1; fi

adb -s "$DEVICE_ID" reverse "tcp:${BACKEND_PORT}" "tcp:${BACKEND_PORT}"
for execution in $(seq 1 "$REPEAT"); do
  for name in "${tests[@]}"; do
    LAST_TEST="$name-$execution"
    for attempt in $(seq 1 "$attempts"); do
      label="$name-$execution-$attempt"
      echo "::group::${label}"
      start_backend "$label"
      adb -s "$DEVICE_ID" shell pm clear "$APP_ID" >/dev/null 2>&1 || true
      adb -s "$DEVICE_ID" logcat -c || true
      started=$SECONDS
      if timeout --signal=INT --kill-after=30s 10m "$FLUTTER_BIN" test "integration_test/client_${name}_e2e_test.dart" \
        --no-pub --device-id "$DEVICE_ID" "${DEFINES[@]}" \
        --reporter expanded --file-reporter "json:$LOG_DIR/$label.json" \
        2>&1 | tee "$LOG_DIR/$label.log"; then
        passed[$name]=$((passed[$name] + 1))
        elapsed[$name]=$((elapsed[$name] + SECONDS - started))
        if (( attempt > 1 )); then retried[$name]=$((retried[$name] + 1)); fi
        stop_backend
        if port_busy; then echo "Backend $label não liberou a porta." >&2; exit 1; fi
        echo '::endgroup::'
        break
      fi
      elapsed[$name]=$((elapsed[$name] + SECONDS - started))
      capture_failure "$label"
      stop_backend
      if port_busy; then echo "Backend $label não liberou a porta." >&2; exit 1; fi
      if (( attempt == attempts )); then failed[$name]=$((failed[$name] + 1)); fi
      echo '::endgroup::'
    done
  done
done

summary="${GITHUB_STEP_SUMMARY:-$LOG_DIR/summary.md}"
{
  echo '### E2E cliente'
  echo '| Teste | Passou | Falhou | Retry bem-sucedido | Duração (s) | Estado |'
  echo '|---|---:|---:|---:|---:|---|'
  for name in "${tests[@]}"; do
    state=pass
    if (( failed[$name] > 0 )); then state=fail; fi
    if (( passed[$name] > 0 && (failed[$name] > 0 || retried[$name] > 0) )); then state=flaky; fi
    echo "| $name | ${passed[$name]} | ${failed[$name]} | ${retried[$name]} | ${elapsed[$name]} | $state |"
  done
} >> "$summary"

for name in "${tests[@]}"; do
  if (( failed[$name] > 0 )); then exit 1; fi
done
echo "E2E passou. Resumo: $summary; logs: $LOG_DIR"
