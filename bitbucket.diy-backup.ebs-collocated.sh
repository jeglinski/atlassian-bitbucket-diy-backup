#!/bin/bash

# This script is meant to be used when the database data directory is collocated in the same volume
# as the home directory. In that scenario 'bitbucket.diy-backup.ebs-home.sh' should be enough to backup / restore a Bitbucket instance.

function no_op {
    echo > /dev/null
}

function bitbucket_prepare_db {
    no_op
}

function bitbucket_backup_db {
    no_op
}

function bitbucket_prepare_db_restore {
    # When PostgreSQL is running as a service with its data on the same volume as the home directory, all its data will
    # restored implicitly when the home volume is restored.  All we need to do is stop the service beforehand.
    sudo service postgresql93 stop
}

function bitbucket_restore_db {
    # All of PostgreSQL's data has already been restored with the home directory volume.  All we need to do is start
    # the service back up again.
    sudo service postgresql93 start
}

function cleanup_old_db_snapshots {
    no_op
}
