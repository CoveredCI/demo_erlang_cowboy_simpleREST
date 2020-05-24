# Documentation validation errors will show up when running
# * `monkey lint` or
# * `monkey fuzz`
# as documentation validation is the first step of fuzzing.
# Note though that once that beofre the 'start' step is executed,
#  no changes to documentation will be taken into account.

OpenAPIv3(
    name = "my simple model",
    # A typo was introduced in documentation in .travis.yml!
    file = "priv/openapi3v1.yml",
    host = "http://localhost:6773",
    ExecStart = """
echo Starting...
until (RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample status) 1>&2; do
    (RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample start) 1>&2
    sleep 1
done
echo Started
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
