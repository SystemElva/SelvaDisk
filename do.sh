#!/usr/bin/env bash

# SPDX-License-Identifier: MPL-2.0



INVOCATION_PATH=$(pwd)
cd $(dirname $0)
CORE_ROOT=$(pwd)
cd ../addons
ADDONS_ROOT=$(pwd)

cd $INVOCATION_PATH

if [[ $# -lt 1 ]];
then
    echo "error: no action given"
    exit 1
fi

build_addons() {

    mkdir -p $CORE_ROOT/.addons

    local ADDON_LIST=$(ls $ADDONS_ROOT)
    for ADDON in $ADDON_LIST;
    do
        # Don't build hidden addons automatically
        if [[ $ADDON == .* ]];
        then
            continue
        fi

        echo ">> $ADDON"

        cd $ADDONS_ROOT/$ADDON/
        zig build $ADDON_SOURCE_PATH $@
        local BUILD_RESULT=$?
        if [[ $BUILD_RESULT != 0 ]];
        then
            continue
        fi
        cd $INVOCATION_PATH

        cp $ADDONS_ROOT/$ADDON/zig-out/lib/*.so $CORE_ROOT/.addons
    done
}

case $1 in
    "b" | "build")
        zig build ${@:2}
        build_addons ${@:2}
        ;;
    "r" | "run")
        $CORE_ROOT/zig-out/bin/SelvaDisk --addons=.addons ${@:2}
        ;;
    *)
        echo "error: unknown action '$1'"
        ;;
esac
