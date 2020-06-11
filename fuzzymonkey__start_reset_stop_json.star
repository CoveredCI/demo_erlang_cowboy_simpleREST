# An example configuration file for fuzzymonkey.co's `monkey`.

## A spec describing Web APIs in the OpenAPIv3 format

# Documentation file can be YAMLv1.2 or in JSON format.
# OpenAPIv3 (formerly known as Swagger) is supported with other formats coming
#  such as Postman Collection, RAML, Paw as well as gRPC and others

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

    # Reset
    ExecReset = """
curl --fail -X DELETE http://localhost:6773/api/1/items
""",

    # Stop
    ExecStop = """
echo Stopping...
RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample stop || true
echo Stopped
""",
)

## A simple check that runs after every HTTP call

def respondsUnder300ms(State, response):
    AssertThat(response["elapsed_ns"]).isAtMost(300e6)

TriggerActionAfterProbe(
    name = "Acceptably fast",
    probe = ("monkey", "http", "response"),
    predicate = lambda State, response: True,
    action = respondsUnder300ms,
)

## A stateful model checking our CRUD Web app

State = {
    "items": {},  # map of ItemID (str) to Item (dict)
}

TriggerActionAfterProbe(
    name = "Remove all items from model state",
    probe = ("monkey", "http", "response"),
    predicate = lambda State, response: all([
        response["request"]["method"] == "DELETE",
        "/items" in response["request"]["url"],
        response["status_code"] == 204,
    ]),
    action = lambda State, response: State["items"].clear(),
)

def compare_all(State, items):
    [AssertThat(item).isIn(items) for itemID, item in State["items"].items()]

TriggerActionAfterProbe(
    name = "Compare items seen with remote data",
    probe = ("monkey", "http", "response"),
    predicate = lambda State, response: all([
        response["request"]["method"] == "GET",
        "/items" in response["request"]["url"],
        response["status_code"] == 200,
    ]),
    action = lambda State, response: compare_all(State, response["json"]),
)

def match_only(method, path, status):
    return lambda State, response: all([
        response["request"]["method"] == method,
        path in response["request"]["url"],
        response["status_code"] == status,
    ])

def item_id(response):
    start = response["request"]["url"].index("/item/")
    return response["request"]["url"][start + len("/item/"):]

TriggerActionAfterProbe(
    name = "Remove item from model state",
    probe = ("monkey", "http", "response"),
    predicate = match_only("DELETE", "/item/", 204),
    action = lambda State, response: State["items"].pop(item_id(response), None),
)

TriggerActionAfterProbe(
    name = "Check reading an item matches model state",
    probe = ("monkey", "http", "response"),
    predicate = match_only("GET", "/item/", 200),
    action = lambda S, resp: compare_all(S, [resp["json"]]),
)

def add_new_item(State, response):
    item = response["json"]
    itemID = str(item["id"])
    AssertThat(State["items"]).doesNotContainKey(itemID)
    State["items"][itemID] = item

TriggerActionAfterProbe(
    name = "Add a new item to model state",
    probe = ("monkey", "http", "response"),
    predicate = match_only("PUT", "/item/", 201),
    action = add_new_item,
)

def check_item_was_merged(State, response):
    print("Updating item #{}".format(item_id(response)))
    print("  with: {}".format(response["request"]["json"]))
    merged = response["json"]
    merged.pop("id")  # PATCH /item/{itemID} returns the ID in the body
    AssertThat(merged).containsAllIn(response["request"]["json"])

TriggerActionAfterProbe(
    name = "Ensure an item gets merged correctly",
    probe = ("monkey", "http", "response"),
    predicate = match_only("PATCH", "/item/", 200),
    action = check_item_was_merged,
)

def replace_existing_item(State, response):
    item = response["json"]
    itemID = str(item["id"])
    if len(State["items"]) != 0:
        # If we have an idea of which items the server contains
        # we can make sure we the item being updated already existed
        AssertThat(State["items"]).containsKey(itemID)
    State["items"][itemID] = item

TriggerActionAfterProbe(
    name = "Updates an item in model state",
    probe = ("monkey", "http", "response"),
    predicate = match_only("PATCH", "/item/", 200),
    action = replace_existing_item,
)
