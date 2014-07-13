#!/usr/bin/env bash

cwd=`pwd`

APT_REPOSITORY_PATH=$cwd/apt_repository
BUILD_SCRIPTS_REPOSITORY_PATH=$cwd/torigoya_package_scripts

echo "Torigoya factory: LOCAL MODE"
echo "Torigoya factory: an apt repository  : $APT_REPOSITORY_PATH"
echo "Torigoya factory: an scripts path    : $BUILD_SCRIPTS_REPOSITORY_PATH"
echo "Torigoya factory: a port of files    : 50080"
echo "Torigoya factory: a port of frontend : 58080"

if [ ! -e $BUILD_SCRIPTS_REPOSITORY_PATH ]; then
    echo "There is no '$BUILD_SCRIPTS_REPOSITORY_PATH' directory."
    echo "  Please clone 'torigoya_package_scripts' repository into there."
    exit -1
fi

./docker.stop.sh &&
./docker.build.sh &&
echo "start container => " &&
sudo docker run \
    -p 50080:80 \
    -p 58080:8080 \
    -v $APT_REPOSITORY_PATH:/etc/apt_repository \
    -v $cwd/placeholder:/etc/placeholder \
    -v $BUILD_SCRIPTS_REPOSITORY_PATH:/etc/package_scripts \
    --name torigoya_factory \
    --detach=true \
    torigoya/factory
