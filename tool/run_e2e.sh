#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${RUN_E2E:-}" != "true" ]]; then
  echo "RUN_E2E=true é obrigatório." >&2
  exit 2
fi

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="${BACKEND_DIR:-$(cd "$APP_DIR/../backend-nhac" && pwd)}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
BACKEND_JAVA_HOME="${BACKEND_JAVA_HOME:-${JAVA_HOME:-}}"
DEVICE_ID="${E2E_DEVICE_ID:-emulator-5554}"
REPEAT="${E2E_REPEAT:-1}"
DB_PORT="${E2E_DB_PORT:-3307}"
BACKEND_PORT="${E2E_BACKEND_PORT:-8080}"
API_BASE_URL="${E2E_API_BASE_URL:-http://10.0.2.2:${BACKEND_PORT}/api/v1}"
LOG_DIR="${E2E_LOG_DIR:-$APP_DIR/build/e2e-logs}"
DB_CONTAINER="nhac-e2e-db-${GITHUB_RUN_ID:-local}-$$"
BACKEND_PID=""

case "$API_BASE_URL" in
  http://10.0.2.2:*|http://127.0.0.1:*|http://localhost:*) ;;
  *)
    echo "API E2E recusada: $API_BASE_URL. Use somente o backend isolado local." >&2
    exit 2
    ;;
esac

if ! [[ "$REPEAT" =~ ^[1-9][0-9]*$ ]]; then
  echo "E2E_REPEAT deve ser um inteiro positivo." >&2
  exit 2
fi

if [[ -z "$BACKEND_JAVA_HOME" || ! -x "$BACKEND_JAVA_HOME/bin/java" ]]; then
  echo "BACKEND_JAVA_HOME deve apontar para um JDK válido." >&2
  exit 2
fi

mkdir -p "$LOG_DIR"

stop_backend() {
  if [[ -n "$BACKEND_PID" ]] && kill -0 "$BACKEND_PID" 2>/dev/null; then
    kill "$BACKEND_PID" 2>/dev/null || true
    wait "$BACKEND_PID" 2>/dev/null || true
  fi
  BACKEND_PID=""
}

cleanup() {
  stop_backend
  if [[ "${E2E_DB_MANAGED:-false}" != "true" ]]; then
    docker rm -f "$DB_CONTAINER" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

if [[ "${E2E_DB_MANAGED:-false}" != "true" ]]; then
  docker run --detach --rm \
    --name "$DB_CONTAINER" \
    --publish "${DB_PORT}:3306" \
    --env MARIADB_DATABASE=nhac_e2e \
    --env MARIADB_USER=nhac_e2e \
    --env MARIADB_PASSWORD=nhac_e2e \
    --env MARIADB_ROOT_PASSWORD=nhac_e2e_root \
    --health-cmd='healthcheck.sh --connect --innodb_initialized' \
    --health-interval=2s \
    --health-timeout=2s \
    --health-retries=30 \
    mariadb:11.4 >/dev/null

  for _ in $(seq 1 60); do
    if [[ "$(docker inspect --format '{{.State.Health.Status}}' "$DB_CONTAINER")" == "healthy" ]]; then
      break
    fi
    sleep 1
  done
  if [[ "$(docker inspect --format '{{.State.Health.Status}}' "$DB_CONTAINER")" != "healthy" ]]; then
    docker logs "$DB_CONTAINER" >"$LOG_DIR/mariadb.log" 2>&1 || true
    echo "MariaDB E2E não ficou saudável." >&2
    exit 1
  fi
fi

for execution in $(seq 1 "$REPEAT"); do
  backend_log="$LOG_DIR/backend-${execution}.log"
  flutter_log="$LOG_DIR/flutter-${execution}.log"

  (
    cd "$BACKEND_DIR"
    JAVA_HOME="$BACKEND_JAVA_HOME" \
    PATH="$BACKEND_JAVA_HOME/bin:$PATH" \
    E2E_DB_URL="jdbc:mariadb://127.0.0.1:${DB_PORT}/nhac_e2e?serverTimezone=UTC&rewriteBatchedStatements=true" \
    E2E_DB_USER=nhac_e2e \
    E2E_DB_PASSWORD=nhac_e2e \
    SERVER_PORT="$BACKEND_PORT" \
      ./mvnw spring-boot:run -Dspring-boot.run.profiles=e2e
  ) >"$backend_log" 2>&1 &
  BACKEND_PID=$!

  backend_ready=false
  for _ in $(seq 1 120); do
    if curl --fail --silent "http://127.0.0.1:${BACKEND_PORT}/actuator/health" | grep -q '"status":"UP"'; then
      backend_ready=true
      break
    fi
    if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
      break
    fi
    sleep 1
  done
  if [[ "$backend_ready" != "true" ]]; then
    tail -n 200 "$backend_log" >&2 || true
    echo "Backend E2E não ficou saudável na execução $execution." >&2
    exit 1
  fi

  {
    echo "Execução E2E $execution/$REPEAT"
    "$FLUTTER_BIN" test integration_test/client_login_e2e_test.dart \
      --device-id "$DEVICE_ID" \
      --dart-define=RUN_E2E=true \
      --dart-define=E2E_MODE=true \
      --dart-define="API_BASE_URL=$API_BASE_URL"
    "$FLUTTER_BIN" test integration_test/client_order_cash_e2e_test.dart \
      --device-id "$DEVICE_ID" \
      --dart-define=RUN_E2E=true \
      --dart-define=E2E_MODE=true \
      --dart-define="API_BASE_URL=$API_BASE_URL"
  } 2>&1 | tee "$flutter_log"

  stop_backend
done

echo "E2E-001..004 passaram em $REPEAT execução(ões). Logs: $LOG_DIR"
