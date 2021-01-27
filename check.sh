#!/bin/bash -eu

set -o errtrace
set -o pipefail

MONKEY=${MONKEY:-monkey}
VVV=${VVV:-}
STAR=${STAR:-}
TIMEOUT=${TIMEOUT:-30s}
SEED=${SEED:-}
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

# Test like CI but sequentially

declare -a STARs Vs Ts
declare -i i=0

STARs[$i]=fuzzymonkey.star
Vs[$i]=0
Ts[$i]=0
((i+=1)) # Funny Bash thing: ((i++)) returns 1 only when i=0

STARs[$i]=fuzzymonkey__start_reset_stop_docker.star
Vs[$i]=0
Ts[$i]=0
((i+=1))

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


info() {
    printf '\e[1;3m%s\e[0m\n' "$*"
}

info Version
$MONKEY --version
rebar3 clean --all
rebar3 as prod release

sed_i() {
    local expr=$1; shift
    local file=$1; shift
    sed "$expr" "$file" >"$file"~
    mv "$file"~ "$file"
}

setup() {
    info "$branch" "$STAR" V="$V" T="$T"
    if [[ $STAR != fuzzymonkey.star ]]; then
        cat "$STAR" >fuzzymonkey.star
    fi
    if [[ $STAR = fuzzymonkey__doc_typo.star ]]; then
        sed_i s/responses:/response:/ priv/openapi3v1.yml
    fi
    if [[ $STAR = fuzzymonkey__doc_typo_json.star ]]; then
        sed_i 's/"responses":/"response":/' priv/openapi3v1.json
    fi
}

check() {
    info fmt
    set +e
    $MONKEY $VVV fmt; code=$?
    set -e
    if  [[ $code -ne 0 ]]; then
        info "$branch" "$STAR" "F=0 (got $code)" ...failed
        return 1
    fi

    info lint
    set +e
    $MONKEY $VVV lint; code=$?
    set -e
    if  [[ $code -ne $V ]]; then
        info "$branch" "$STAR" "V=$V (got $code)" T="$T" ...failed
        return 1
    fi

    timeout=$TIMEOUT
    if [[ $T -ne 0 ]]; then
        timeout=5m
    fi
    intensity=999 # TODO: drop --intensity

    if [[ -z "$SEED" ]]; then
        info fuzz no-shrinking
        set +e
        $MONKEY $VVV fuzz --intensity=$intensity --time-budget=$timeout --no-shrinking; code=$?
        set -e
        if  [[ $code -ne $T ]]; then
            info "$branch" "$STAR" V="$V" "T=$T (got $code)" ...failed
            return 1
        fi

        if [[ $V -eq 0 ]]; then
            info pastseed
            seedfile=$(mktemp)
            set +e
            $MONKEY pastseed >"$seedfile" 2>&1; code=$?
            set -e
            SEED=$(cat "$seedfile")
            rm "$seedfile"
            if [[ $code -ne 0 ]] || [[ -z "$SEED" ]]; then
                info "$branch" "$STAR" V="$V" "S=0 (got $code)" ...failed
                echo "$seedfile"
                echo "$SEED"
                return 1
            fi
        fi
    else
        info "Given SEED=$SEED"
    fi

    info fuzz shrink seed
    set +e
    $MONKEY $VVV fuzz --intensity=$intensity --time-budget=$timeout --seed=$SEED; code=$?
    set -e
    if  [[ $code -ne $T ]]; then
        info "$branch" "$STAR" V="$V" "T=$T (got $code)" ...failed
        return 1
    fi

    info "$branch" "$STAR" V="$V" T="$T" ...passed
    return 0
}

cleanup() {
    if [[ -n "$failed" ]]; then
        if [[ -n "${CI:-}" ]]; then
            $MONKEY logs | tail -n999
            echo '---'
            $MONKEY logs | head
        fi
    fi

    if curl --output /dev/null --silent --fail --head http://localhost:6773/api/1/items; then
        info Some instance is still running on localhost!
        return 1
    fi
    if curl --output /dev/null --silent --fail --head http://my_image:6773/api/1/items; then
        info Some instance is still running on my_image!
        return 1
    fi

    git checkout -- fuzzymonkey.star
    git checkout -- priv/openapi3v1.yml
    git checkout -- priv/openapi3v1.json
}

errors=0
for i in "${!STARs[@]}"; do
    V=${Vs[$i]}
    T=${Ts[$i]}

    [[ -n "$STAR" ]] && [[ $STAR != "${STARs[$i]}" ]] && continue

    STAR=${STARs[$i]} V=$V T=$T setup
    STAR=${STARs[$i]} V=$V T=$T check || { ((errors+=1)); failed=t; }
    STAR=${STARs[$i]} V=$V T=$T failed=${failed:-} cleanup

    [[ -n "$STAR" ]] && [[ $STAR = "${STARs[$i]}" ]] && break
done
exit "$errors"
