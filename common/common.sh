#!/bin/bash

[ -n "$DEBUG" ] && set -x
set -o errexit

# extract DEBUGINFO
# Should be set to TRUE to produce debuginfo
export DEBUGINFO=${DEBUGINFO:-FALSE}

# working environment
export WORKSPACE=${WORKSPACE:-$(pwd)}
export TF_CONFIG_DIR=${TF_CONFIG_DIR:-"${HOME}/.tf"}
export TF_DEVENV_PROFILE="${TF_CONFIG_DIR}/dev.env"

[ -e "$TF_DEVENV_PROFILE" ] && source "$TF_DEVENV_PROFILE"

# determined variables
if [[ "$OSTYPE" == "linux-gnu" ]]; then
  export DISTRO=$(cat /etc/*release | egrep '^ID=' | awk -F= '{print $2}' | tr -d \")
elif [[ "$OSTYPE" == "darwin"* ]]; then
  export DISTRO="macosx"
else
  echo "Unsupported platform."
  exit 1
fi

# working build directories
if [ -z "${CONTRAIL_DIR+x}" ] ; then
  # not defined => use default
  CONTRAIL_DIR=${WORKSPACE}/contrail 
elif [ -z "$CONTRAIL_DIR" ] ; then
  # defined empty => dont bind contrail dir to host: tf jenkins
  CONTRAIL_DIR=${WORKSPACE}/contrail 
  BIND_CONTRAIL_DIR=false
fi
export CONTRAIL_DIR
export DEVENV_USER=${DEVENV_USER:-$(id -nu)}

# build environment preparation options
export CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-"localhost:5000"}
# check if container registry is in ip:port format
if [[ $CONTAINER_REGISTRY == *":"* ]]; then
    export REGISTRY_IP=$(echo $CONTAINER_REGISTRY | cut -f 1 -d ':')
    export REGISTRY_PORT=$(echo $CONTAINER_REGISTRY | cut -f 2 -d ':')
else
    # no need to setup local registry while using docker hub
    export CONTRAIL_DEPLOY_REGISTRY=0
    # skip updating insecure registry for docker
    export CONTRAIL_SKIP_INSECURE_REGISTRY=1
fi
export RPM_REPO_IP='localhost'
export RPM_REPO_PORT='6667'
export REGISTRY_CONTAINER_NAME=${REGISTRY_CONTAINER_NAME:-"tf-dev-env-registry"}
export DEVENV_CONTAINER_NAME=${DEVENV_CONTAINER_NAME:-"tf-dev-sandbox"}
export CONTRAIL_PARALLEL_BUILD=${CONTRAIL_PARALLEL_BUILD:-true}

# tf-dev-env sandbox parameters
export DEVENV_IMAGE_NAME=${DEVENV_IMAGE_NAME:-"tf-dev-sandbox"}
export DEVENV_TAG=${DEVENV_TAG:-"latest"}
export DEVENV_PUSH_TAG=${DEVENV_PUSH_TAG:-"frozen"}
export DEVENV_IMAGE=${DEVENV_IMAGE:-"${DEVENV_IMAGE_NAME}:${DEVENV_TAG}"}

# RHEL specific build options
export ENABLE_RHSM_REPOS=${ENABLE_RHSM_REPOS:-'false'}

# versions info
export CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG:-'dev'}
# note: there is spaces available in names below
export VENDOR_NAME=${VENDOR_NAME:-"TungstenFabric"}
export VENDOR_DOMAIN=${VENDOR_DOMAIN:-"tungsten.io"}

# Contrail repo branches options
export CONTRAIL_BRANCH=${CONTRAIL_BRANCH:-${GERRIT_BRANCH:-'master'}}
export CONTRAIL_FETCH_REPO=${CONTRAIL_FETCH_REPO:-"https://github.com/tungstenfabric/tf-vnc"}

# Docker options
if [ -z "${DOCKER_VOLUME_OPTIONS}" ] ; then
  export DOCKER_VOLUME_OPTIONS="z"
  if [[ $DISTRO == "macosx" ]]; then
    # Performance issue with osxfs, this option is making the
    # writes async from the container to the host. This means a
    # difference can happen from the host POV, but that should not
    # be an issue since we are not expecting anything to update
    # the source code. Based on test this option increase the perf
    # of about 10% but it still quite slow comparativly to a host
    # using GNU/Linux.
    DOCKER_VOLUME_OPTIONS+=",delegated"
  fi
fi
