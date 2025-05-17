#!/usr/bin/env bash

cd $(dirname $0)
PROJECT_ROOT=$(pwd)

build_core() {
    zig build "$@"
        mv "$PROJECT_ROOT/zig-out/bin/SelvaDisk" . 
}

build_addons() {
    mkdir -p $PROJECT_ROOT/.addons
    for ADDON_NAME in $(ls "$PROJECT_ROOT/addons")
    do
        echo ">> $ADDON_NAME"
        cd "$PROJECT_ROOT/addons/$ADDON_NAME"
        zig build
        cp zig-out/lib/*.so "$PROJECT_ROOT/.addons/"
    done
}

build_project() {
    build_core "$@"
    local STATUS=$?
    if [[ $STATUS != 0 ]];
    then
        return $STATUS
    fi
    build_addons "$@"
    return $?
}



if [[ $# -lt 1 ]];
then
    echo "error: action needed"
    echo "  try: $0 build"
    echo "  or   $0 run"
    exit 1
fi

case $1 in
    "b" | "build")
        build_project ${@:2}
        ;;

    "bc" | "build-core")
        build_core ${@:2}
        ;;

    "ba" | "build-addons")
        build_addons ${@:2}
        ;;

    "r" | "run")
        # Build SelvaDisk if it hasn't been built before.
        if [[ ! -f "$PROJECT_ROOT/SelvaDisk" ]];
        then
            build_project
            STATUS=$?
            if [[ $STATUS != 0 ]];
            then
                echo "error: failed building software, won't attempt running it" >&2
                exit 1
            fi

        fi
        $PROJECT_ROOT/SelvaDisk ${@:2}
        ;;

    *)
        echo "error: unknown action ($1)"
        ;;
esac
