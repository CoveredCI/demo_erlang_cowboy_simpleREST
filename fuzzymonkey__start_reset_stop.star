version: 0

documentation:
  kind: openapi_v2
  file: priv/openapi2v1.yml
  host: localhost
  port: 6773

## One can either specify
## * start & stop
## * start & reset & stop
## * just reset

start:
  - |
    until RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample status 1>&2; do
      RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample start 1>&2
      sleep 1
    done

reset:
  - curl --fail -X DELETE http://localhost:6773/api/1/items

stop:
  - RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample stop 1>&2
