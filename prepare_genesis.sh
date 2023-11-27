#!/usr/bin/env bash
set -o errexit nounset pipefail

: "${EPOCH:=692}"
: "${WORKDIR:=${HOME}}"
: "${GIT_BRANCH:=release-6.9.0-rc.10}"
: "${GIT_REPO:=release-v6.9.0-genesis-registration}"

# used by Makefile
export SOURCE_PATH="${LIBRA_FRAMEWORK_PATH}"
export EPOCH="${EPOCH}"
export GIT_REPO="${GIT_REPO}"

LIBRA_REPO_NAME="libra-framework"
LIBRA_FRAMEWORK_PATH="${WORKDIR}/${LIBRA_REPO_NAME}"
DOT_LIBRA_PATH="${WORKDIR}/.libra"
LIBRA_GIT_REPO="https://github.com/0LNetworkCommunity/${LIBRA_REPO_NAME}"
GENESIS_PATH="${LIBRA_FRAMEWORK_PATH}/tools/genesis"

function confirm() {
    while true; do
        read -p "(YES/NO/CANCEL) " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            [Cc]* ) exit;;
            * ) echo "Please answer YES, NO, or CANCEL.";;
        esac
    done
}

function cleanup_libra_framework() {
  echo "Cleaning up libra-framework repo....."
  rm -rf -- "${LIBRA_FRAMEWORK_PATH}"

  echo "Cleaning up libra binary..."
  LIBRA_BIN_PATH=$(which libra || true)
  rm -f -- "${LIBRA_BIN_PATH}"  "~/.cargo/bin/libra"
}

function cleanup_dot_libra() {
  if [ -d "${DOT_LIBRA_PATH}" ]; then
    CURRENT_DATE_TIME=$(date +"%Y-%m-%d-%T")
    BAK_FOLDER="${DOT_LIBRA_PATH}-${CURRENT_DATE_TIME}.bak"
    echo "Backing up ${DOT_LIBRA_PATH} into ${BAK_FOLDER}"
    mv -- "${DOT_LIBRA_PATH}" "${BAK_FOLDER}"
fi
mkdir -- "${DOT_LIBRA_PATH}"
}

function install_dependencies() {
  PRE_COMMAND=()
  if [ "$(whoami)" != 'root' ]; then
    PRE_COMMAND=(sudo)
  fi
  "${PRE_COMMAND[@]}" apt update -y && "${PRE_COMMAND[@]}" apt install git make -y
}

function pull_repo() {
  install_dependencies
  (
    cd -- "${WORKDIR}" && \
    git clone ${LIBRA_GIT_REPO} && \
    cd -- "${LIBRA_FRAMEWORK_PATH}" && \
    git fetch --all && \
    git checkout "${GIT_BRANCH}"
  )
}

##### BEGIN CLEANUP
if [ -d "${LIBRA_FRAMEWORK_PATH}" ]; then
  printf "\033[1;31mWould you like to recreate libra-framework folder?\033[0m\n"
  if confirm; then
    cleanup_libra_framework
    pull_repo
  fi

  else
    # create from scratch
    pull_repo
fi
cleanup_dot_libra

###### END CLEANUP


### BEGIN CONFIRM CODE VERSION
GIT_HASH=$(cd -- "${LIBRA_FRAMEWORK_PATH}" && git log -n 1 --pretty=format:"%H")
echo -- "${GIT_HASH}"
printf "\033[1;31mPlease confirm the git hash\033[0m\n"
if ! confirm; then
  echo "Exiting..."
  exit 0;
fi
### END CONFIRM CODE VERSION

### BEGIN Build and install libra bins
(
  cd -- "${GENESIS_PATH}" && \
  make install
)
read -r -p "Please provide your GitHub token : " git_token
echo "${git_token}" > "${DOT_LIBRA_PATH}/github_token.txt"
### END Build and install libra bins

# REGISTER GENESIS
(
  cd -- "${GENESIS_PATH}" && \
  make register && \
  make legacy
)
printf "\033[0;32mWait for the coordinator for the next step\033[0m\n"

