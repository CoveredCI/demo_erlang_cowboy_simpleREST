# Data describing Web APIs
OpenAPIv3(
    name = "my simple model",
    # Note: references to schemas in `file` are resolved relative to file's location.
    file = "priv/openapi3v1.yml",
    host = "http://localhost:6773",

    # Note: commands are executed in shells sharing the same environment variables,
    # with `set -e` and `set -o pipefail` flags on.

    # The following get executed once per test
    #   so have these commands complete as fast as possible.
    # Also, make sure that each test starts from a clean slate
    #   otherwise results will be unreliable.
    ExecStart = """
echo starting 1>&2
until RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample status 1>&2; do
    RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample start 1>&2
    sleep 1
    echo started? 1>&2
done
  """,
    ExecStop = """
echo Stopping... 1>&2
if ! RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample stop 1>&2; then
    echo Failed to stop 1>&2
    exit 1
fi
echo stopped 1>&2
    """,
)


TriggerActionAfterProbe(
    name = "Acceptably fast",
    probe = ("monkey", "http", "response"),
    predicate = lambda State, response: True,
    action = lambda State, response: AssertThat(response['elapsed_ns']).isAtMost(300e6),
)
