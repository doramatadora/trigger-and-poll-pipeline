# Trigger CircleCI Pipeline Orb and Optionally Poll for Success

`doramatadora/trigger-and-poll-pipeline@1.0.0`

This orb allows you to trigger a CircleCI pipeline and optionally poll for its success. You can trigger pipelines from a branch or tag, and poll for workflows or individual jobs within a workflow.

## Usage

### Trigger a pipeline

```yaml
version: 2.1
orbs:
  trigger-and-poll-pipeline: doramatadora/trigger-and-poll-pipeline@1.0.0

workflows:
  trigger-and-poll-pipeline-workflow:
    jobs:
      - trigger-and-poll-pipeline/trigger:
          project_slug: github/doramatadora/trigger-and-poll-pipeline
          branch: main
          definition_id: $DEFINITION_ID
          token: $CIRCLECI_PAT
          parameters: color=red,size=medium
          poll_interval: 10
          poll_timeout: 300
```

### Parameters

| Parameter              | Type    | Default | Description                                                                        |
| ---------------------- | ------- | ------- | ---------------------------------------------------------------------------------- |
| `token`                | string  | -       | CircleCI PAT.                                                                      |
| `project_slug`         | string  | -       | The project slug. Example: `github/org/repo`.                                      |
| `definition_id`        | string  | -       | Definition ID of the pipeline to run.                                              |
| `branch`               | string  | `main`  | Branch to trigger the pipeline from. Not compatible with `tag`.                    |
| `tag`                  | string  | `""`    | Tag to trigger the pipeline from. Not compatible with `branch`.                    |
| `parameters`           | string  | `""`    | Comma-separated key=value pairs to pass as pipeline parameters.                    |
| `workflow_name`        | string  | `""`    | Optional workflow name to poll for success. Required if `job_name` is set.         |
| `job_name`             | string  | `""`    | Optional job name to poll for success inside `workflow_name`.                      |
| `poll_interval`        | integer | `0`     | Seconds between polling attempts. `0` disables polling.                            |
| `poll_timeout`         | integer | `0`     | Maximum number of seconds to poll. `0` means no timeout.                           |


## Examples

### Trigger from a branch

```yaml
jobs:
  - trigger-and-poll-pipeline/trigger:
      project_slug: github/doramatadora/trigger-and-poll-pipeline
      branch: main
      definition_id: $DEFINITION_ID
      token: $CIRCLECI_PAT
      parameters: color=red,size=medium
```

### Trigger from a tag

```yaml
jobs:
  - trigger-and-poll-pipeline/trigger:
      project_slug: github/doramatadora/trigger-and-poll-pipeline
      tag: v1.2.3
      definition_id: $DEFINITION_ID
      token: $CIRCLECI_PAT
      parameters: color=blue,size=large
```

### Poll for a specific workflow

```yaml
jobs:
  - trigger-and-poll-pipeline/trigger:
      project_slug: github/org/another-repo
      branch: develop
      definition_id: $DEFINITION_ID
      token: $CIRCLECI_PAT
      workflow_name: build-and-test
      poll_interval: 10
      poll_timeout: 1200
```

### Poll for a specific job in a workflow

```yaml
jobs:
  - trigger-and-poll-pipeline/trigger:
      project_slug: github/org/another-repo
      branch: develop
      definition_id: $DEFINITION_ID
      token: $CIRCLECI_PAT
      workflow_name: build-and-test
      job_name: test
      poll_interval: 10
```

## Requirements

* [jq](https://jqlang.org) must be available in the CircleCI environment.
* A CircleCI Personal Access Token (PAT) with permission to trigger pipelines.

## License

MIT
