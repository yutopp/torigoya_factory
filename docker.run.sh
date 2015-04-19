#!/usr/bin/env bash

cwd=`pwd`

APT_REPOSITORY_PATH=$cwd/apt_repository
PACKAGES_PATH=$cwd/packages_shadow

echo "Torigoya factory: an apt repository  : $APT_REPOSITORY_PATH"
echo "Torigoya factory: packages path      : $PACKAGES_PATH"
echo "Torigoya factory: a port of files    : 80"
echo "Torigoya factory: a port of frontend : 8080"

cp -r ../torigoya_proc_profiles -T proc_profiles
cd proc_profiles
./generate.sh -l ${APT_REPOSITORY_PATH}/available_package_table
cd ..

./docker.stop.sh &&
./docker.build.sh &&
echo "start container => " &&
sudo docker run \
    -p 80:80 \
    -p 8080:8080 \
    -v $APT_REPOSITORY_PATH:/etc/apt_repository \
    -v $PACKAGES_PATH:/usr/local/torigoya \
    -v $cwd/placeholder:/etc/placeholder \
    -v $cwd/database:/etc/database \
    -v $cwd/tmp:/etc/tmp \
    --name torigoya_factory \
    --detach=true \
    torigoya/factory

rm -rf proc_profiles
