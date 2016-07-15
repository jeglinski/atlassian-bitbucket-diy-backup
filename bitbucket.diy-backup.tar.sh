#!/bin/bash


function bitbucket_prepare_backup_archive {
    check_command "tar"
}

function bitbucket_backup_archive {
    mkdir -p ${BITBUCKET_BACKUP_ARCHIVE_ROOT}
    BITBUCKET_BACKUP_ARCHIVE_NAME=`perl -we 'use Time::Piece; my $sydTime = localtime; print "bitbucket-", $sydTime->strftime("%Y%m%d-%H%M%S-"), substr($sydTime->epoch, -3), ".tar.gz"'`

    info "Archiving ${BITBUCKET_BACKUP_ROOT} into ${BITBUCKET_BACKUP_ARCHIVE_ROOT}/${BITBUCKET_BACKUP_ARCHIVE_NAME}"
    tar -czf ${BITBUCKET_BACKUP_ARCHIVE_ROOT}/${BITBUCKET_BACKUP_ARCHIVE_NAME} -C ${BITBUCKET_BACKUP_ROOT} .
    info "Archived ${BITBUCKET_BACKUP_ROOT} into ${BITBUCKET_BACKUP_ARCHIVE_ROOT}/${BITBUCKET_BACKUP_ARCHIVE_NAME}"
}

function bitbucket_prepare_restore_archive {
    BITBUCKET_BACKUP_ARCHIVE_NAME=$1

    if [ -z ${BITBUCKET_BACKUP_ARCHIVE_NAME} ]; then
        echo "Usage: $0 <backup-file-name>.tar.gz"  > /dev/stderr
        if [ ! -d ${BITBUCKET_BACKUP_ARCHIVE_ROOT} ]; then
            error "${BITBUCKET_BACKUP_ARCHIVE_ROOT} does not exist!"
        else
            available_backups
        fi
        exit 99
    fi

    if [ ! -f ${BITBUCKET_BACKUP_ARCHIVE_ROOT}/${BITBUCKET_BACKUP_ARCHIVE_NAME} ]; then
        error "${BITBUCKET_BACKUP_ARCHIVE_ROOT}/${BITBUCKET_BACKUP_ARCHIVE_NAME} does not exist!"
        available_backups
        exit 99
    fi

    # Check and create BITBUCKET_HOME
    if [ -e ${BITBUCKET_HOME} ]; then
        bail "Cannot restore over existing contents of ${BITBUCKET_HOME}. Please rename or delete this first."
    fi
    mkdir -p ${BITBUCKET_HOME}
    chown ${BITBUCKET_UID}:${BITBUCKET_GID} ${BITBUCKET_HOME}

    # Setup restore paths
    BITBUCKET_RESTORE_ROOT=$(mktemp -d /tmp/bitbucket.diy-restore.XXXXXX)
    BITBUCKET_RESTORE_DB=${BITBUCKET_RESTORE_ROOT}/bitbucket-db
    BITBUCKET_RESTORE_HOME=${BITBUCKET_RESTORE_ROOT}/bitbucket-home
}

function bitbucket_restore_archive {
    if [ -f ${BITBUCKET_BACKUP_ARCHIVE_NAME} ]; then
        BITBUCKET_BACKUP_ARCHIVE_NAME=${BITBUCKET_BACKUP_ARCHIVE_NAME}
    else
        BITBUCKET_BACKUP_ARCHIVE_NAME=${BITBUCKET_BACKUP_ARCHIVE_ROOT}/${BITBUCKET_BACKUP_ARCHIVE_NAME}
    fi
    tar -xzf ${BITBUCKET_BACKUP_ARCHIVE_NAME} -C ${BITBUCKET_RESTORE_ROOT}

    info "Extracted ${BITBUCKET_BACKUP_ARCHIVE_NAME} into ${BITBUCKET_RESTORE_ROOT}"
}

function bitbucket_cleanup_archive {
    # Cleanup of old backups is not currently implemented
    no_op
}

function available_backups {
	echo "Available backups:"  > /dev/stderr
	ls ${BITBUCKET_BACKUP_ARCHIVE_ROOT}
}