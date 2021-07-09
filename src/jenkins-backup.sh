#!/usr/bin/env bash
#
# Copyright (c) 2021 Eurotech S.p.A.
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

set -eo pipefail

JENKINS_HOME=${1}
DEST_S3_BUCKET=${2}

TMP_DIR=$(mktemp -d)
ARC_DIR=${TMP_DIR}/archive

BACKUP_FILE="${TMP_DIR}/backup-$(date "+%Y%m%dT%H%M%S")"

usage() {
    echo "usage: $(basename "$0") <jenkins_home_path> <target_s3_bucket>"
}

main() {
    if [ -z "${JENKINS_HOME}" ] || [ -z "${DEST_S3_BUCKET}" ] ; then
        usage >&2
        exit 1
    fi

    echo "Using stagin directory ${ARC_DIR}"

    mkdir "${ARC_DIR}"
    pushd "${ARC_DIR}" > /dev/null; mkdir plugins jobs users secrets nodes; popd > /dev/null

    # Copy configurations
    if [ -z "${SKIP_CONFIGS}" ]; then
        cp "${JENKINS_HOME}"/*.xml "${ARC_DIR}"
    fi

    # Copy jobs
    if [ -d "${JENKINS_HOME}/jobs" ] && [ -z "${SKIP_JOBS}" ]; then
        rsync -a --include='config.xml' --include='nextBuildNumber' --include='*/' --exclude='*' "${JENKINS_HOME}/jobs" "${ARC_DIR}/jobs"
    fi

    # Copy secrets
    if [ -d "${JENKINS_HOME}/secrets" ] && [ -z "${SKIP_SECRETS}" ]; then
        rsync -a --exclude='master.key' "${JENKINS_HOME}/secrets" "${ARC_DIR}/secrets"
    fi

    # Copy nodes
    if [ -d "${JENKINS_HOME}/nodes" ] && [ -z "${SKIP_NODES}" ]; then
        cp -R "${JENKINS_HOME}/nodes" "${ARC_DIR}/nodes"
    fi

    # Copy users
    if [ -d "${JENKINS_HOME}/users" ] && [ -z "${SKIP_USERS}" ]; then
        cp -R "${JENKINS_HOME}/users" "${ARC_DIR}/users"
    fi

    # Copy users
    if [ -d "${JENKINS_HOME}/plugins" ] && [ -z "${SKIP_PLUGINS}" ]; then
        cp -R "${JENKINS_HOME}/plugins" "${ARC_DIR}/plugins"
    fi

    # Create archive
    tar cfJ "${BACKUP_FILE}" "${ARC_DIR}"

    # Upload file
    echo "Uploading file to ${DEST_S3_BUCKET}"
    /usr/local/bin/aws s3 mv "${BACKUP_FILE}" "${DEST_S3_BUCKET}"
}

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

main
