#!/bin/bash
# Function to check a status and exit if it's terminal.
# See: https://circleci.com/docs/api/v2/index.html#tag/Workflow
check_status() {
    local name="$1"
    local status="$2"

    if [ "$status" = "success" ]; then
        echo "🟢 $name passed"
        exit 0
    elif [ "$status" != "running" ] && [ "$status" != "on_hold" ] && [ "$status" != "blocked" ]; then
        echo "🔴 $name: $status"
        exit 1
    fi
}

# PAT to use for authentication.
TOKEN=$(circleci env subst "${TOKEN}")

# The project slug. This can be found on the CircleCI project settings page.
PROJECT_SLUG=$(circleci env subst "${PROJECT_SLUG}")

# Definition ID of the pipeline to run. This can be found on the CircleCI project settings page.
DEFINITION_ID=$(circleci env subst "${DEFINITION_ID}")

# Branch where the pipeline will be run from. Not compatible with tag. Defaults to main.
BRANCH=$(circleci env subst "${BRANCH}")
BRANCH=${BRANCH:-main}

# Tag where the pipeline will be run from. Not compatible with branch.
TAG=$(circleci env subst "${TAG}")

# List of comma separated key=value parameters.
PARAMETERS=$(circleci env subst "${PARAMETERS}")

# A workflow name to poll for success, or empty to poll all workflows.
WORKFLOW_NAME=$(circleci env subst "${WORKFLOW_NAME}")

# A job name to poll for success in WORKFLOW_NAME. Script will not exit if other jobs fail.
JOB_NAME=$(circleci env subst "${JOB_NAME}")

# Poll interval in seconds. 0 means no polling – just trigger (fire and forget).
POLL_INTERVAL=$(circleci env subst "${POLL_INTERVAL}")
POLL_INTERVAL=$((POLL_INTERVAL + 0))

# Poll for success for this many seconds. 0 means no timeout. Defaults to 3600 (1 hour).
POLL_TIMEOUT=$(circleci env subst "${POLL_TIMEOUT}")
POLL_TIMEOUT=$((POLL_TIMEOUT + 0))

if ! command -v jq >/dev/null 2>&1; then
    echo "jq (https://jqlang.org/) is required"
    exit 1
fi

if [ -z "$PROJECT_SLUG" ]; then
    echo "A project slug is required"
    exit 1
fi

if [ -z "$DEFINITION_ID" ]; then
    echo "A definition ID is required"
    exit 1
fi

if [ -z "$TOKEN" ]; then
    echo "A token is required"
    exit 1
fi

if [ -n "$JOB_NAME" ] && [ -z "$WORKFLOW_NAME" ]; then
    echo "A workflow name is required when a job name is provided"
    exit 1
fi

if [ -n "$TAG" ]; then
    ref_type="tag"
    ref_value="$TAG"
else
    ref_type="branch"
    ref_value="$BRANCH"
fi

echo "Triggering from $ref_type $ref_value"

if [ -n "$PARAMETERS" ]; then
    PARAMS=$(jq -Rn --arg params "$PARAMETERS" '
        (
            $params 
            | split(",") 
            | map(
                split("=") 
                | { (.[0]): 
                    if .[1] == "true" then true
                    elif .[1] == "false" then false
                    elif (. [1] | test("^-?[0-9]+$")) then (. [1] | tonumber)
                    else .[1]
                    end
                    }
                )
            | add
        )
    ')

    echo "With parameters $PARAMS"
else
    PARAMS="{}"
fi

DATA=$(jq -n \
    --arg definition_id "$DEFINITION_ID" \
    --arg ref_value "$ref_value" \
    --argjson params "$PARAMS" \
    --arg ref_type "$ref_type" '
    {
        definition_id: $definition_id,
        config: { ($ref_type): $ref_value },
        checkout: { ($ref_type): $ref_value },
        parameters: $params
    }'
)

PIPELINE_ID=$(curl -X POST "https://circleci.com/api/v2/project/${PROJECT_SLUG}/pipeline/run" \
  --header "Circle-Token: ${TOKEN}" \
  --header "content-type: application/json" \
  --data "${DATA}" | jq -r '.id')

if [ "$POLL_INTERVAL" -gt 0 ]; then
    # Start timer
    SECONDS=0

    while true; do
        echo "Polling for pipeline ${PIPELINE_ID} every ${POLL_INTERVAL} seconds, elapsed ${SECONDS} seconds..."

        # Enforce timeout
        if [ "$POLL_TIMEOUT" -gt 0 ] && [ "$SECONDS" -ge "$POLL_TIMEOUT" ]; then
            echo "Timeout reached, aborting"
            exit 1
        fi

        WORKFLOWS_JSON=$(curl -s -H "Circle-Token: ${TOKEN}" \
            "https://circleci.com/api/v2/pipeline/${PIPELINE_ID}/workflow")

        if [ -n "$WORKFLOW_NAME" ]; then
            # Single workflow mode
            WORKFLOW_ID=$(echo "$WORKFLOWS_JSON" | jq -r --arg workflow "$WORKFLOW_NAME" \
                '.items[] | select(.name==$workflow) | .id')
            WORKFLOW_STATUS=$(echo "$WORKFLOWS_JSON" | jq -r --arg workflow "$WORKFLOW_NAME" \
                '.items[] | select(.name==$workflow) | .status')

            if [ -z "$WORKFLOW_ID" ]; then
                echo "Workflow ${WORKFLOW_NAME} not yet created, waiting..."
                sleep "${POLL_INTERVAL}"
                continue
            else
                if [ -n "$JOB_NAME" ]; then
                    # Single job mode
                    JOBS=$(curl -s -H "Circle-Token: ${TOKEN}" \
                        "https://circleci.com/api/v2/workflow/${WORKFLOW_ID}/job")

                    JOB_STATUS=$(echo "$JOBS" | jq -r --arg job "$JOB_NAME" \
                        '.items[] | select(.name==$job) | .status')
                    if [ -z "$JOB_STATUS" ]; then
                        echo "Job ${JOB_NAME} not found in workflow ${WORKFLOW_NAME}"
                        exit 1
                    else
                        check_status "$JOB_NAME" "$JOB_STATUS"
                    fi
                else
                    # Entire workflow mode
                    check_status "$WORKFLOW_NAME" "$WORKFLOW_STATUS"
                fi
            fi
        else
            # All workflows mode
            all_done=true

            while read -r name status; do
                case "$status" in
                    success) ;;
                    running|on_hold|blocked) all_done=false ;;
                    *) echo "🔴 $name: $status"; exit 1 ;;
                esac
            done < <(echo "$WORKFLOWS_JSON" | jq -r '.items[] | "\(.name) \(.status)"')

            if $all_done; then
                echo "🟢 All workflows passed"
                exit 0
            else
                echo "Waiting for workflows to finish..."
            fi
        fi

        sleep "${POLL_INTERVAL}"
    done
else
    echo "Triggered pipeline ${PIPELINE_ID}"
fi
