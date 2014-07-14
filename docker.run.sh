#!/usr/bin/env bash

cwd=`pwd`

APT_REPOSITORY_PATH=$cwd/apt_repository
INSTALLED_BINARIES=$cwd/installed_binaries

echo "Torigoya factory: an apt repository  : $APT_REPOSITORY_PATH"
echo "Torigoya factory: binaries path      : $INSTALLED_BINARIES"
echo "Torigoya factory: a port of files    : 80"
echo "Torigoya factory: a port of frontend : 8080"

./docker.stop.sh &&
./docker.build.sh &&
echo "start container => " &&
sudo docker run \
    -p 80:80 \
    -p 8080:8080 \
    -v $APT_REPOSITORY_PATH:/etc/apt_repository \
    -v $cwd/placeholder:/etc/placeholder \
    -v $INSTALLED_BINARIES:/usr/local/torigoya \
    --name torigoya_factory \
    --detach=true \
    torigoya/factory
