#!/usr/bin/env bash

INVOCATION_PATH=$(pwd)
cd $INVOCATION_PATH/$(dirname $0)
SELVADISK_PATH=$(pwd)
cd $INVOCATION_PATH



build_single_extension() {
    local EXTENSION_NAME=$1
    local EXTENSION_PATH="$SELVADISK_PATH/.extensions/$EXTENSION_NAME"
    local FUNCTION_ENTRY_PATH=$(pwd)

    cd "$EXTENSION_PATH"
    zig build --release=safe
    cd "$FUNCTION_ENTRY_PATH"

    mv $EXTENSION_PATH/zig-out/lib/*.so $SELVADISK_PATH/.extensions/
}

build_all_extensions() {
    if [[ -d "$SELVADISK_PATH/.extensions" ]];
    then
        rm -r "$SELVADISK_PATH/.extensions"
    fi
    mkdir -p "$SELVADISK_PATH/.extensions"

    for EXTENSION_NAME in $(ls -A "$SELVADISK_PATH/.extensions");
    do
        build_single_extension $EXTENSION_NAME
    done
}

build_core() {
    local FUNCTION_ENTRY_PATH="$SELVADISK_PATH/core/"

    cd "$FUNCTION_ENTRY_PATH"
    zig build --release=safe
    cd "$FUNCTION_ENTRY_PATH"

    local STATUS=$?
    if [[ $STATUS != 0 ]];
    then
        echo "error(build-system): failed building core."
        exit $STATUS
    fi
}

build_runner() {
    local FUNCTION_ENTRY_PATH="$SELVADISK_PATH/runner/"

    cd "$SELVADISK_PATH/runner"
    zig build --release=safe
    cd "$FUNCTION_ENTRY_PATH"

    local STATUS=$?
    if [[ $STATUS != 0 ]];
    then
        echo "error(build-system): failed building runner."
        exit $STATUS
    fi

    mv "$SELVADISK_PATH/runner/zig-out/bin/SelvaDisk" "$INVOCATION_PATH/selvadisk.elf"
}

build_all() {
    build_core
    build_runner
    build_all_extensions
}

if [[ $# -lt 1 ]];
then
    echo "error: action needed. Try: $0 help"
fi

case $1 in
    "b" | "build-all")
        build_all ${@:2}
        ;;
    "bc" | "build-core")
        build_core ${@:2}
        ;;

    "be" | "build-extensions")
        build_all_extensions ${@:2}
        ;;

    "h" | "help")
        cat "$SELVADISK_PATH/assets/do.sh/help-texts/general.txt"
        ;;

    *)
        echo "error: invalid action ('$1') Try: $0 help"
        ;;
esac
