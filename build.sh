#!/bin/bash
#
# Selects appropriate base images and Qemu archs 
# (but doesn’t yet check if they all exist and all - that’s your homework ;) 
# and also removes unnecessary qemu for amd64
#
# https://github.com/multiarch/qemu-user-static
# https://lobradov.github.io/Building-docker-multiarch-images/
# https://ownyourbits.com/2018/06/27/running-and-building-arm-docker-containers-in-x86/
#

FILE_PATH=$(readlink -f $(dirname $0))  #/home/media/docker-certs-extraction
FILE_NAME=$(basename $0)                #build.sh
FILE_NAME=${FILE_NAME%.*}               #build
FILE_DATE=$(date +'%Y%m%d-%H%M%S')
FILE_LOG="/var/log/$FILE_NAME.log"

DOCKER_USER="joweisberg"

if [ -z "$1" ]; then
  echo "* Require one parameter as respository name:"
  echo "* ./$(basename $0) $DOCKER_USER/${FILE_PATH##*/}"
  exit 1
fi

if [ $(apt list --installed 2> /dev/null | grep qemu | wc -l) -eq 0 ]; then
  echo "* Running ARM containers"
  sudo apt -y install qemu-user
  docker run --rm --privileged multiarch/qemu-user-static:register --reset
fi

echo "* Create different Dockerfile per architecture"
for docker_arch in amd64 arm32v6 arm64v8; do
  case ${docker_arch} in
    amd64   ) qemu_arch="x86_64" ;;
    arm32v6 ) qemu_arch="arm" ;;
    arm64v8 ) qemu_arch="aarch64" ;;    
  esac
  cp Dockerfile.cross Dockerfile.${docker_arch}
  sed -i "s|__BASEIMAGE_ARCH__|${docker_arch}|g" Dockerfile.${docker_arch}
  sed -i "s|__QEMU_ARCH__|${qemu_arch}|g" Dockerfile.${docker_arch}
  if [ ${docker_arch} == "amd64" ]; then
    sed -i "/__CROSS_/d" Dockerfile.${docker_arch}
  else
    sed -i "s/__CROSS_//g" Dockerfile.${docker_arch}
  fi
done

echo "* Download OS architecture qmenu"
for target_arch in x86_64 arm aarch64; do
  wget -Nq https://github.com/multiarch/qemu-user-static/releases/download/v4.2.0-7/x86_64_qemu-${target_arch}-static.tar.gz
  tar -xvf x86_64_qemu-${target_arch}-static.tar.gz
done

echo "* Building and tagging individual images"
for arch in amd64 arm32v6 arm64v8; do
  docker build -f Dockerfile.${arch} -t $DOCKER_USER/$1:${arch}-latest .
  if [ $? -ne 0 ]; then
    echo "* Error on building image $1"
    exit 1
  fi
  docker push $DOCKER_USER/$1:${arch}-latest
done

echo "* Building a multi-arch manifest"
docker manifest create --amend $DOCKER_USER/$1:latest $DOCKER_USER/$1:amd64-latest $DOCKER_USER/$1:arm32v6-latest $DOCKER_USER/$1:arm64v8-latest
docker manifest push --purge $DOCKER_USER/$1:latest

echo "* Cleanup unnecessary files"
rm -f Dockerfile.a* qemu-* x86_64_qemu-*

exit 0