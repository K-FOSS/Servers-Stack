#!/bin/sh
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

#
# Run SSH Image
#
runSSHImage() {
  local IMAGE="${1}"
  local CMD="${2}"

  local RESULT=

  docker run -it --rm -v ${PWD}/Scripts/SSH/passwd:/etc/passwd -v ${TMP_PATH}/SSH:/config/.ssh ${IMAGE} ${CMD}
}

#
# SSH Functions
#

getHostKey() {
  local HOST="${1}"
  local HOST_KEY="$()"

  echo $(docker run -it --rm -v ${PWD}/Scripts/SSH/passwd:/etc/passwd -v ${TMP_PATH}/SSH:/config/.ssh ${OPENSSH_KEYSCAN_IMAGE} -H -t ecdsa-sha2-nistp256 ${HOST} | docker run -i kristianfoss/programs-tail:tail-stable-scratch -n 1)
}

log "LOG" "This script must be run from the swarm manager. Sleeping for 5 seconds to allow for exit\n"

if [ "${DEBUG}" -ne 1 ]; then
  sleep 5
else
  log "DEBUG" "Script in debug mode, skipping sleeping. Beware"
fi

log "DEBUG" "SCRIPT: ${SCRIPT}\nBIN_PATH: ${BIN_PATH}\nTMP_PATH: ${TMP_PATH}"

log "LOG" "\n\nEnter all Hostnames/IP Address of the other hosts in this cluster. Seperated by spaces"

read -p 'Hostnames/IPs: ' HOSTS

if [ -z "${HOSTS}" ]; then
  log "LOG" "HOSTS field is empty, exiting"
  exit 1
fi

log "LOG" "\nEnter the username for accessing all hosts"

read -p 'Username: ' USERNAME

log "LOG" "Generating SSH Key. If prompted for Key password, leave blank"

runSSHImage ${OPENSSH_KEYGEN_IMAGE} '-q -f /config/.ssh/id_rsa'

SSH_PUBLIC_KEY="$(cat ${TMP_PATH}/SSH/id_rsa.pub)"

for HOST in ${HOSTS}; do
  echo "Setting up ${HOST}"
  getHostKey "${HOST}" >> ${TMP_PATH}/SSH/known_hosts

  runSSHImage "${OPENSSH_SSH_IMAGE}" "${USERNAME}@${HOST} echo '${SSH_PUBLIC_KEY}' >> ~/.ssh/authorized_keys"
done

finish() {
  echo "${HOSTS}" > "${HOSTS_FILE}"

  mkdir -p ${TMP_PATH}/rclone

  touch ${TMP_PATH}/rclone/rclone.conf

  echo "[Server]\ntype = sftp\nuser = ${USERNAME}\nkey_pem = $(awk '{printf "%s\\\\n", $0}' <${TMP_PATH}/SSH/id_rsa)" >> ${TMP_PATH}/rclone/rclone.conf
}

finish