# `Env(name, default="")` resolves environment variable `name` from the shell calling `monkey`.
# `Env` returns a string and defaults to the empty string.
# Resolving happens while linting models and before any execution.
# Resolved values are accessible in reset executors as read-only.

OpenAPIv3(
    name = "my simple model",
    file = "priv/openapi3v1.yml",
    host = "http://{host}:6773".format(host = Env("my_host", "127.0.0.1")),
    ExecStart = """
echo Starting...
until (RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample status) 1>&2; do
    (RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample start) 1>&2
    sleep 1
done
echo Started
""",
    ExecReset = "[[ 204 = $(curl --silent --output /dev/null --write-out '%{http_code}' -X DELETE http://$my_host:6773/api/1/items) ]]",
    ExecStop = """
echo Stopping...
RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample stop || true
echo Stopped $my_host:6773
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
