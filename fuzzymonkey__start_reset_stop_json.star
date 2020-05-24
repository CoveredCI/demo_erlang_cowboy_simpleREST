# Documentation file can be YAMLv1.2 or in JSON format.
# OpenAPIv3 (formerly known as Swagger) is supported with other formats coming
#  such as Postman Collection, RAML, Paw as well as gRPC and others

OpenAPIv3(
    name = "my simple model",
    file = "priv/openapi3v1.json",
    host = "http://localhost:6773",
    ExecStart = """
echo Starting...
until (RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample status) 1>&2; do
    (RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample start) 1>&2
    sleep 1
done
echo Started
""",
    ExecReset = """
curl --fail -X DELETE http://localhost:6773/api/1/items
""",
    ExecStop = """
echo Stopping...
RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample stop || true
echo Stopped
""",
)

def respondsUnder300ms(State, response):
    AssertThat(response["elapsed_ns"]).isAtMost(300e6)

TriggerActionAfterProbe(
    name = "Acceptably fast",
    probe = ("monkey", "http", "response"),
    predicate = lambda State, response: True,
    action = respondsUnder300ms,
)
