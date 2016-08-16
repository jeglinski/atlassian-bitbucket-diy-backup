#!/bin/bash

# -------------------------------------------------------------------------------------
# The Disaster Recovery script to promote a standby Bitbucket Data Center instance.
#
# Ensure you are using this script in accordance with the following document:
# https://confluence.atlassian.com/display/BitbucketServer/Bitbucket+Data+Center+disaster+recovery
#
# It requires the following configuration file:
#   bitbucket.diy-backup.vars.sh
#   which can be copied from bitbucket.diy-backup.vars.sh.example and customized.
# -------------------------------------------------------------------------------------

# Ensure the script terminates whenever a required operation encounters an error
set -e

SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/common.sh"

##########################################################

info "Promoting standby Bitbucket Data Center"

promote_standby_db
promote_standby_home

success "Successfully promoted standby instance"

info "This script may have appended properties to your ${BITBUCKET_HOME}shared/bitbucket.properties file,
 please check this file before continuing the failover process."
info "Ensure you continue the failover steps to successfully failover to your standby instance"