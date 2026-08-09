#!/usr/bin/env bash
set -euo pipefail

SONAR_HOST_URL="${SONAR_HOST_URL:-http://localhost:9000}"
SONAR_CONTAINER_NAME="${SONAR_CONTAINER_NAME:-sonarqube-ci}"
SONAR_IMAGE="${SONAR_IMAGE:-sonarqube:community}"
QUALITY_GATE_NAME="${QUALITY_GATE_NAME:-CI Security Gate}"
SONAR_PROJECT_KEY="${SONAR_PROJECT_KEY:-three-tier-project}"
SONAR_PROJECT_NAME="${SONAR_PROJECT_NAME:-Three-Tier-Project}"

cleanup_existing_container() {
  docker rm -f "${SONAR_CONTAINER_NAME}" >/dev/null 2>&1 || true
}

wait_for_sonarqube() {
  echo "Waiting for SonarQube to become available..."

  for attempt in $(seq 1 90); do
    status="$(curl -fsS "${SONAR_HOST_URL}/api/system/status" 2>/dev/null | jq -r '.status // empty' || true)"

    if [[ "${status}" == "UP" ]]; then
      echo "SonarQube is ready."
      return 0
    fi

    echo "SonarQube status: ${status:-starting} (${attempt}/90)"
    sleep 5
  done

  echo "SonarQube failed to start in time."
  docker logs "${SONAR_CONTAINER_NAME}" || true
  return 1
}

configure_sonarqube() {
  local admin_password token
  admin_password="$(openssl rand -hex 24)"

  curl --fail-with-body -sS \
    -u admin:admin \
    -X POST "${SONAR_HOST_URL}/api/users/change_password" \
    --data-urlencode "login=admin" \
    --data-urlencode "previousPassword=admin" \
    --data-urlencode "password=${admin_password}" >/dev/null

  token="$(
    curl --fail-with-body -sS \
      -u "admin:${admin_password}" \
      -X POST "${SONAR_HOST_URL}/api/user_tokens/generate" \
      --data-urlencode "name=github-actions-${GITHUB_RUN_ID:-local}-$(date +%s)" \
      | jq -r '.token'
  )"

  if [[ -z "${token}" || "${token}" == "null" ]]; then
    echo "Unable to generate SonarQube token."
    return 1
  fi

  echo "::add-mask::${token}"

  # This ephemeral server is created for every CI run. A small custom gate
  # blocks the pipeline on security or reliability degradation without needing
  # long-lived SonarQube history.
  curl --fail-with-body -sS \
    -u "${token}:" \
    -X POST "${SONAR_HOST_URL}/api/qualitygates/create" \
    --data-urlencode "name=${QUALITY_GATE_NAME}" >/dev/null

  curl --fail-with-body -sS \
    -u "${token}:" \
    -X POST "${SONAR_HOST_URL}/api/qualitygates/create_condition" \
    --data-urlencode "gateName=${QUALITY_GATE_NAME}" \
    --data-urlencode "metric=security_rating" \
    --data-urlencode "op=GT" \
    --data-urlencode "error=1" >/dev/null

  curl --fail-with-body -sS \
    -u "${token}:" \
    -X POST "${SONAR_HOST_URL}/api/qualitygates/create_condition" \
    --data-urlencode "gateName=${QUALITY_GATE_NAME}" \
    --data-urlencode "metric=reliability_rating" \
    --data-urlencode "op=GT" \
    --data-urlencode "error=1" >/dev/null

  curl --fail-with-body -sS \
    -u "${token}:" \
    -X POST "${SONAR_HOST_URL}/api/projects/create" \
    --data-urlencode "project=${SONAR_PROJECT_KEY}" \
    --data-urlencode "name=${SONAR_PROJECT_NAME}" >/dev/null

  curl --fail-with-body -sS \
    -u "${token}:" \
    -X POST "${SONAR_HOST_URL}/api/qualitygates/select" \
    --data-urlencode "gateName=${QUALITY_GATE_NAME}" \
    --data-urlencode "projectKey=${SONAR_PROJECT_KEY}" >/dev/null

  if [[ -n "${GITHUB_ENV:-}" ]]; then
    {
      echo "SONAR_TOKEN=${token}"
      echo "SONAR_HOST_URL=${SONAR_HOST_URL}"
    } >> "${GITHUB_ENV}"
  fi

  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
      echo "token=${token}"
      echo "host_url=${SONAR_HOST_URL}"
    } >> "${GITHUB_OUTPUT}"
  fi

  if [[ -z "${GITHUB_ENV:-}" && -z "${GITHUB_OUTPUT:-}" ]]; then
    echo "SONAR_TOKEN=${token}"
    echo "SONAR_HOST_URL=${SONAR_HOST_URL}"
  fi
}

cleanup_existing_container

sudo sysctl -w vm.max_map_count=524288 >/dev/null
sudo sysctl -w fs.file-max=131072 >/dev/null

docker run -d \
  --name "${SONAR_CONTAINER_NAME}" \
  --ulimit nofile=131072:131072 \
  --ulimit nproc=8192:8192 \
  -p 9000:9000 \
  "${SONAR_IMAGE}" >/dev/null

wait_for_sonarqube
configure_sonarqube
