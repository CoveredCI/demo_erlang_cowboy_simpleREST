version: 0

documentation:
  kind: openapi_v2
  file: priv/openapi2v1.yml
  host: localhost
  port: '{{ env "CONTAINER_PORT" }}'


# A simple setup with Docker

start:
  - docker --version
  - docker build --compress --force-rm --tag my_image .
  - CONTAINER_ID=$(docker run --rm --detach --publish 6773 my_image)
  - >
    cmd="$(docker port $CONTAINER_ID 6773/tcp)"
    CONTAINER_PORT=$(python -c "_, port = '$cmd'.split(':'); print(port)")
    URL=http://localhost:$CONTAINER_PORT/api/1/items
  - until curl --output /dev/null --silent --fail --head $URL; do sleep 1; done

reset:
  - curl --fail -X DELETE $URL

stop:
  - docker stop --time 1 $CONTAINER_ID >/dev/null
