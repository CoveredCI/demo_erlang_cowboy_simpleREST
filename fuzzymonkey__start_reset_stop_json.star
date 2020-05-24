version: 0

# Documentation file can be YAMLv1.2 or in JSON format.
# OpenAPIv2 (formerly known as Swagger) is supported with other formats coming
#  such as Postman Collection, RAML, Paw, ...

documentation:
  kind: openapi_v2
  file: priv/openapi2v1.json
  host: localhost
  port: 6773


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
