# An example configuration file for fuzzymonkey.co's `monkey`.

## A spec describing Web APIs in the OpenAPIv3 format

# Documentation validation errors will show up when running
# * `monkey lint` or
# * `monkey fuzz`
# as documentation validation is the first step of fuzzing.
# Note though that once that beofre the 'start' step is executed,
#  no changes to documentation will be taken into account.

OpenAPIv3(
    name = "my simple model",
    # A typo was introduced in the documentation!
    file = "priv/openapi3v1.yml",
    host = "http://localhost:6773",

    # Start
    ExecStart = """
echo Starting...
until (RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample status) 1>&2; do
    (RELX_REPLACE_OS_VARS=true ./_build/prod/rel/sample/bin/sample daemon) 1>&2
    sleep 1
done
echo Started
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

# Return State in order to commit its changes:
def remove_all_items(State, _response):
    State["items"].clear()
    return State

TriggerActionAfterProbe(
    name = "Remove all items from model state",
    probe = ("monkey", "http", "response"),
    predicate = lambda State, response: all([
        response["request"]["method"] == "DELETE",
        "/items" in response["request"]["url"],
        response["status_code"] == 204,
    ]),
    action = remove_all_items,
)

def compare_all(State, items):
    for item_id, item in State["items"].items():
        AssertThat(item).isIn(items)

TriggerActionAfterProbe(
    name = "Compare items seen with remote data",
    probe = ("monkey", "http", "response"),
    predicate = lambda State, response: all([
        response["request"]["method"] == "GET",
        "/items" in response["request"]["url"],
        response["status_code"] == 200,
    ]),
    action = lambda State, response: compare_all(State, response["body"]),
)

def match_only(method, path, status):
    return lambda State, response: all([
        response["request"]["method"] == method,
        path in response["request"]["url"],
        response["status_code"] == status,
    ])

def item_id(response):
    start = response["request"]["url"].index("/item/")
    return str(int(response["request"]["url"][start + len("/item/"):]))

def remove_single_item(State, response):
    State["items"].pop(item_id(response), None)
    return State

TriggerActionAfterProbe(
    name = "Remove item from model state",
    probe = ("monkey", "http", "response"),
    predicate = match_only("DELETE", "/item/", 204),
    action = remove_single_item,
)

def ensure_matching_contents_if_model_knows_about_item(S, response):
    item = response["body"]
    item_id = str(int(item["id"]))
    if item_id in S["items"]:
        AssertThat(S["items"][item_id]).isEqualTo(item)

TriggerActionAfterProbe(
    name = "Check reading an item matches model state",
    probe = ("monkey", "http", "response"),
    predicate = match_only("GET", "/item/", 200),
    action = ensure_matching_contents_if_model_knows_about_item,
)

def add_item(State, response):
    """Adds or updates a single item in State"""
    item = response["body"]
    item_id = str(int(item["id"]))
    State["items"][item_id] = item
    return State

TriggerActionAfterProbe(
    name = "Add/update a single item in model state",
    probe = ("monkey", "http", "response"),
    predicate = lambda State, response: any([
        match_only("PUT", "/item/", 201)(State, response),
        match_only("POST", "/item/", 200)(State, response),
        match_only("PATCH", "/item/", 200)(State, response),
    ]),
    action = add_item,
)

#
# Note: you can ensure your assertions work as you intend
#
# This passes (which can be surprising):
AssertThat({"my": "value"}).containsAllIn({"my": 42})

def check_item_was_merged(_State, response):
    """Ensures all pairs in request payload appear in response body"""
    patch = response["request"]["body"]
    print("Updating item #{}".format(item_id(response)))
    print("  with: {}".format(patch))
    merged = response["body"]
    merged.pop("id")  # PATCH /item/{item_id} returns the ID in the body
    for key, value in patch.items():
        AssertThat(merged).containsItem(key, value)

TriggerActionAfterProbe(
    name = "Ensure an item gets merged correctly",
    probe = ("monkey", "http", "response"),
    predicate = match_only("PATCH", "/item/", 200),
    action = check_item_was_merged,
)
