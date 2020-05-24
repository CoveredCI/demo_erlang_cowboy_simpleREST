version: 0

documentation:
  kind: openapi_v2
  file: priv/openapi2v1.json
  host: localhost
  port: 6773


# If an error occurs while running a step's commands:
# * the error is displayed
# * the `stop` step is attempted (if different to current step)
# * `monkey` exits with code 7

start:
  - |
    until RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample status 1>&2; do
      RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample start 1>&2
      sleep 1
    done

reset:
  - true  # Next command will fail due to non-zero exit code
  - false

stop:
  - RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample stop 1>&2
