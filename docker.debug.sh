#!/usr/bin/env bash

cwd=`pwd`

APT_REPOSITORY_PATH=$cwd/apt_repository
PACKAGES_PATH=$cwd/packages_shadow

echo "Torigoya factory: DEBUGGING"
echo "Torigoya factory: an apt repository  : $APT_REPOSITORY_PATH"
echo "Torigoya factory: packages path      : $PACKAGES_PATH"
echo "Torigoya factory: a port of files    : 50080"
echo "Torigoya factory: a port of frontend : 58080"

./docker.stop.sh &&
./docker.build.sh &&
echo "start container => " &&
sudo docker run \
    -p 50080:80 \
    -p 58080:8080 \
    -v $APT_REPOSITORY_PATH:/etc/apt_repository \
    -v $PACKAGES_PATH:/usr/local/torigoya \
    -v $cwd/placeholder:/etc/placeholder \
    -v $cwd/torigoya_package_scripts:/etc/package_scripts \
    --name torigoya_factory \
    --detach=true \
    torigoya/factory
