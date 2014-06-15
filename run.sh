#!/usr/bin/env bash

cwd=`pwd`

./build.sh &&
echo "start container => " &&
sudo docker run \
    -p 80:80 \
    -p 8080:8080 \
    -v $cwd/apt_repository:/etc/apt_repository \
    --name torigoya_bs \
    torigoya/factory
