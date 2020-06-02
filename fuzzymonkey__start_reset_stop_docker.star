# A simple setup with Docker

OpenAPIv3(
    name = "my simple model",
    file = "priv/openapi3v1.yml",
    host = "http://localhost:6773",

    # Start
    ExecStart = """
docker --version

docker build --compress --force-rm --tag my_image .
docker run --rm --detach --publish 6773:6773 --name my_image my_image
until curl --output /dev/null --silent --fail --head http://localhost:6773/api/1/items; do
  sleep 1
done
""",

    # Reset
    ExecReset = """
curl --fail -X DELETE http://localhost:6773/api/1/items
""",

    # Stop
    ExecStop = """
docker stop --time 1 my_image
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
