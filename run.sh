#!/usr/bin/env bash

cwd=`pwd`

APT_REPOSITORY_PATH=$cwd/apt_repository
BUILD_SCRIPTS_REPOSITORY_PATH=$cwd/../torigoya_package_scripts

./build.sh &&
echo "start container => " &&
sudo docker run \
    -p 80:80 \
    -p 8080:8080 \
    -v $APT_REPOSITORY_PATH:/etc/apt_repository \
    -v $cwd/placeholder:/etc/placeholder \
    -v $BUILD_SCRIPTS_REPOSITORY_PATH:/etc/package_scripts \
    --name torigoya_bs \
    --detach=true \
    torigoya/factory
