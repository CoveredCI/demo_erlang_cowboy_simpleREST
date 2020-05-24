#!/bin/bash -eux

# Bend it like Travis, to debug monkey

set -o errtrace
set -o pipefail

declare -a STARs Vs Ts
declare -i i=0

STARs[$i]=fuzzymonkey__start_reset_stop_docker.star
Vs[$i]=0
Ts[$i]=0
((i+=1)) # Funny Bash thing: ((i++)) returns 1 only when i=0

STARs[$i]=fuzzymonkey__start_reset_stop.star
Vs[$i]=0
Ts[$i]=0
((i+=1))

STARs[$i]=fuzzymonkey__start_reset_stop_json.star
Vs[$i]=0
Ts[$i]=0
((i+=1))

STARs[$i]=fuzzymonkey__start_reset_stop_failing_script.star
Vs[$i]=0
Ts[$i]=7
((i+=1))

STARs[$i]=fuzzymonkey.star
Vs[$i]=0
Ts[$i]=0
((i+=1))

STARs[$i]=fuzzymonkey__env.star
Vs[$i]=0
Ts[$i]=0
((i+=1))

STARs[$i]=fuzzymonkey__doc_typo.star
Vs[$i]=2
Ts[$i]=2
((i+=1))

STARs[$i]=fuzzymonkey__doc_typo_json.star
Vs[$i]=2
Ts[$i]=2
((i+=1))


monkey=${MONKEY:-monkey}
$monkey --version
rebar3 as prod release
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
info() {
    printf '\e[1;3m%s\e[0m\n' "$*"
}

setup() {
    info $branch $STAR V=$V T=$T
    if [[ $STAR != fuzzymonkey.star ]]; then cp $STAR fuzzymonkey.star; fi
    if [[ $STAR == fuzzymonkey__doc_typo.star ]]; then
        sed -i s/consumes:/consume:/ priv/openapi3v1.yml
    fi
    if [[ $STAR == fuzzymonkey__doc_typo_json.star ]]; then
        sed -i 's/"consumes":/"consume":/' priv/openapi3v1.json
    fi
}

check() {
    set +e
    $monkey lint; code=$?
    set -e
    if  [[ $code -ne $V ]]; then
        info $branch $STAR V=$V T=$T ...failed
        return 1
    fi
    set +e
    $monkey fuzz; code=$?
    set -e
    if  [[ $code -ne $T ]]; then
        info $branch $STAR V=$V T=$T ...failed
        return 1
    fi
    info $branch $STAR V=$V T=$T ...passed
    return 0
}

cleanup() {
    git checkout -- fuzzymonkey.star
    git checkout -- priv/openapi3v1.yml
    git checkout -- priv/openapi3v1.json

    $monkey exec stop
    if curl --output /dev/null --silent --fail --head http://localhost:6773/api/1/items; then
        info Some instance is still running on localhost!
        return 1
    fi
    if curl --output /dev/null --silent --fail --head http://my_image:6773/api/1/items; then
        info Some instance is still running on my_image!
        return 1
    fi
}

errors=0
STAR=${STAR:-}
for i in "${!STARs[@]}"; do
    V=${Vs[$i]}
    T=${Ts[$i]}

    if [[ -z "$STAR" ]]; then
        STAR=${STARs[$i]} V=$V T=$T setup
        STAR=${STARs[$i]} V=$V T=$T check || ((errors+=1))
        STAR=${STARs[$i]} V=$V T=$T cleanup
    else
        if [[ $STAR = ${STARs[$i]} ]]; then
            STAR=$STAR V=$V T=$T setup
            STAR=$STAR V=$V T=$T check || ((errors+=1))
            STAR=$STAR V=$V T=$T cleanup
            break
        fi
    fi
done
exit $errors
