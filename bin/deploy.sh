#!/bin/sh
BIN_PATH="./bin"
SYNC_PATH="${BIN_PATH}/sync.sh"

## Debug mode: Skips some sleep statements and adds more logging
DEBUG=${DEBUG_MODE:-0}

# Full path of this script
SCRIPT="$(readlink -f "${0}")"

# Full path to ./bin folder
BIN_PATH="$(dirname "${SCRIPT}")"

## Full path to TMP Directory
TMP_PATH="$(readlink -f ${BIN_PATH}/../TMP)"

## Path to .HOSTS File
HOSTS_FILE="${TMP_PATH}/.HOSTS"

USERNAME="$(cat ${TMP_PATH}/rclone/rclone.conf | sed -n -e 's/^.*user = //p')"

## 
HOSTS=$(cat ${HOSTS_FILE})

OPENSSH_IMAGE="kristianfoss/programs-openssh"
OPENSSH_KEYGEN_TAG="ssh-keygen-cli-main-scratch"
OPENSSH_KEYGEN_IMAGE="${OPENSSH_IMAGE}:${OPENSSH_KEYGEN_TAG}"

#
# OpenSSH Keyscan Image
#
OPENSSH_KEYSCAN_TAG="ssh-keyscan-cli-main-scratch"
OPENSSH_KEYSCAN_IMAGE="${OPENSSH_IMAGE}:${OPENSSH_KEYSCAN_TAG}"

#
# OpenSSH SSH CLI Image
#
OPENSSH_SSH_TAG="ssh-cli-main-scratch"
OPENSSH_SSH_IMAGE="${OPENSSH_IMAGE}:${OPENSSH_SSH_TAG}"

OPENSSH_RUN_CMD="docker run -it --rm -v ${PWD}/Scripts/SSH/passwd:/etc/passwd -v ${TMP_PATH}/SSH:/config/.ssh"

RCLONE_RUN_CMD=""


#
# Log to console
# 
# LEVEL DEBUG LOG
#
log() {
  local LEVEL="${1:-"DEBUG"}"
  local MESSAGE="${2}"

  if [ "${LEVEL}" = "LOG" ]; then
    echo "${MESSAGE}"
    return 0
  fi

  if [ "${LEVEL}" = "DEBUG" ]; then
    if [ "${DEBUG}" -eq 1 ]; then
      echo "[DEBUG]: ${MESSAGE}"
    fi

    return 0
  fi
}

log "LOG" "This script must be run from the swarm manager. Sleeping for 5 seconds to allow for exit\n"

if [ "${DEBUG}" -ne 1 ]; then
  sleep 5
else
  log "DEBUG" "Script in debug mode, skipping sleeping. Beware"
fi

for HOST in ${HOSTS}; do
  echo "HOST: ${HOST}"

  docker run -it --rm -v ${PWD}/Scripts/SSH/passwd:/etc/passwd -v ${PWD}:/tmp/source:ro -v ${TMP_PATH}/rclone:/config/rclone -e XDG_CONFIG_HOME=/config -v ${TMP_PATH}/SSH:/config/.ssh -e RCLONE_SFTP_HOST=${HOST} kristianfoss/programs-rclone:rclone-main-scratch sync /tmp/source Server:TMP/Lab2

  ${OPENSSH_RUN_CMD} ${OPENSSH_SSH_IMAGE} ${USERNAME}@${HOST} 'cd ~/TMP/Lab2 && docker-compose up -d MetricBeat Filebeat' 
done

docker-compose up -d MetricBeat Filebeat