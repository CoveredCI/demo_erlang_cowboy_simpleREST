# If an error occurs while running a step's commands:
# * the error is displayed
# * `monkey` exits with code 7

# NOTE: you may want to cleanup after a fuzzing run with
#  $ monkey exec stop

OpenAPIv3(
    name = "my simple model",
    file = "priv/openapi3v1.json",
    host = "http://localhost:6773",

    # Start
    ExecStart = """
echo Starting...
until (RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample status) 1>&2; do
    (RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample start) 1>&2
    sleep 1
done
echo Started
""",

    # A failing reset script
    ExecReset = """
true  # Next command will fail due to non-zero exit code
false
""",

    # Stop
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
