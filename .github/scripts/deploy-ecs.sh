#!/usr/bin/env bash
set -euo pipefail

required_variables=(
  ECS_CLUSTER
  FRONTEND_SERVICE
  BACKEND_SERVICE
  FRONTEND_TASK_FAMILY
  BACKEND_TASK_FAMILY
  FRONTEND_IMAGE
  BACKEND_IMAGE
)

for variable in "${required_variables[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    echo "Required environment variable is missing: ${variable}" >&2
    exit 1
  fi
done

register_revision() {
  local family="$1"
  local container_name="$2"
  local image="$3"
  local output_file="$4"

  aws ecs describe-task-definition \
    --task-definition "${family}" \
    --query taskDefinition \
    --output json > "${output_file}.current.json"

  jq \
    --arg container "${container_name}" \
    --arg image "${image}" \
    '(.containerDefinitions[] | select(.name == $container) | .image) = $image
     | del(
         .taskDefinitionArn,
         .revision,
         .status,
         .requiresAttributes,
         .compatibilities,
         .registeredAt,
         .registeredBy
       )' \
    "${output_file}.current.json" > "${output_file}.new.json"

  aws ecs register-task-definition \
    --cli-input-json "file://${output_file}.new.json" \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text
}

frontend_task_arn="$(register_revision "${FRONTEND_TASK_FAMILY}" frontend "${FRONTEND_IMAGE}" frontend-task)"
backend_task_arn="$(register_revision "${BACKEND_TASK_FAMILY}" backend "${BACKEND_IMAGE}" backend-task)"

echo "Updating ${FRONTEND_SERVICE} to ${frontend_task_arn}"
aws ecs update-service \
  --cluster "${ECS_CLUSTER}" \
  --service "${FRONTEND_SERVICE}" \
  --task-definition "${frontend_task_arn}" >/dev/null

echo "Updating ${BACKEND_SERVICE} to ${backend_task_arn}"
aws ecs update-service \
  --cluster "${ECS_CLUSTER}" \
  --service "${BACKEND_SERVICE}" \
  --task-definition "${backend_task_arn}" >/dev/null

aws ecs wait services-stable \
  --cluster "${ECS_CLUSTER}" \
  --services "${FRONTEND_SERVICE}" "${BACKEND_SERVICE}"

echo "ECS services are stable."
