# -------------------------------------------------------------------------------------
# A backup and restore strategy for Amazon EBS
# -------------------------------------------------------------------------------------

source "${SCRIPT_DIR}/aws-common.sh"

function prepare_backup_disk {
    # Validate that all the configuration parameters have been provided to avoid bailing out and leaving Bitbucket locked
    check_config_var "EBS_VOLUME_MOUNT_POINT_AND_DEVICE_NAMES"

    for volume in "${EBS_VOLUME_MOUNT_POINT_AND_DEVICE_NAMES[@]}"; do
        if ! [[ "${volume}" =~ ^.+:.+$ ]]; then
            error "EBS volume '${volume}' should be specified with the format MOUNT_POINT:DEVICE_NAME."
            bail "Please update EBS_VOLUME_MOUNT_POINT_AND_DEVICE_NAMES in '${BACKUP_VARS_FILE}'"
        fi

        local device_name="$(echo "${volume}" | cut -d ":" -f2)"
        local volume_id="$(find_attached_ebs_volume "${device_name}")"
        if [ -z "${volume_id}" -o "${volume_id}" = "null" ]; then
            error "Device name ${device_name} specified in ${BACKUP_VARS_FILE} under EBS_VOLUME_MOUNT_POINT_AND_DEVICE_NAMES could not be resolved to a volume."
            bail "See bitbucket.diy-backup.vars.sh.example for the defaults."
        fi
    done
}

function backup_disk {
    # Freeze the filesystems to ensure consistency
    freeze_directories

    # Take a snapshot of each volume
    for volume in "${EBS_VOLUME_MOUNT_POINT_AND_DEVICE_NAMES[@]}"; do
        local device_name="$(echo "${volume}" | cut -d ":" -f2)"
        local volume_id="$(find_attached_ebs_volume "${device_name}")"
        snapshot_ebs_volume "${volume_id}" "Perform backup: ${PRODUCT} EBS volume snapshot for ${device_name}" "${device_name}"
    done

    # Unfreeze the filesystems as soon as the EBS snapshots have been taken
    unfreeze_directories
}

function prepare_restore_disk {
    check_config_var "HOME_DIRECTORY_MOUNT_POINT"
    check_config_var "EBS_VOLUME_MOUNT_POINT_AND_DEVICE_NAMES"
    check_config_var "BITBUCKET_UID"
    check_config_var "AWS_AVAILABILITY_ZONE"
    check_config_var "RESTORE_DISK_VOLUME_TYPE"

    local snapshot_tag="$1"

    if [ -z "${snapshot_tag}" ]; then
        # Get the list of available snapshot tags to assist with selecting a valid one
        list_available_ebs_snapshots
        bail "Please select the tag for the snapshot that you wish to restore"
    fi

    if [ "io1" = "${RESTORE_DISK_VOLUME_TYPE}" ]; then
        check_config_var "RESTORE_DISK_IOPS" \
            "The provisioned IOPS must be set as RESTORE_DISK_IOPS in ${BACKUP_VARS_FILE} when choosing 'io1' \
            volume type for EBS volumes"
    fi

    # Validate EBS volumes by finding the EBS volume ID and snapshot ID for each volume specified
    for volume in "${EBS_VOLUME_MOUNT_POINT_AND_DEVICE_NAMES[@]}"; do
        local device_name="$(echo "${volume}" | cut -d ":" -f2)"
        find_attached_ebs_volume "${device_name}"
        retrieve_ebs_snapshot_id "${snapshot_tag}" "${device_name}"
    done
}

function restore_disk {
    local snapshot_tag="$1"

    unmount_ebs_volumes

    for volume in "${EBS_VOLUME_MOUNT_POINT_AND_DEVICE_NAMES[@]}"; do
        local mount_point="$(echo "${volume}" | cut -d ":" -f1)"
        local device_name="$(echo "${volume}" | cut -d ":" -f2)"
        local volume_id="$(find_attached_ebs_volume "${device_name}")"
        local snapshot_id="$(retrieve_ebs_snapshot_id "${snapshot_tag}" "${device_name}")"

        detach_volume "${volume_id}"
        info "Restoring data from snapshot '${snapshot_id}' into a '${RESTORE_DISK_VOLUME_TYPE}' volume at mount point '${mount_point}'"
        create_and_attach_volume "${snapshot_id}" "${RESTORE_DISK_VOLUME_TYPE}" "${RESTORE_DISK_IOPS}" \
                "${device_name}" "${mount_point}"
    done

    remount_ebs_volumes

    cleanup_repository_locks "${HOME_DIRECTORY_MOUNT_POINT}/data/repositories"
    for volume in "${EBS_VOLUME_MOUNT_POINT_AND_DEVICE_NAMES[@]}"; do
        mount_point="$(echo "${volume}" | cut -d ":" -f1)"
        if [ "${mount_point}" != "${HOME_DIRECTORY_MOUNT_POINT}" ]; then
            cleanup_repository_locks "${mount_point}/repositories/*/*"
        fi
    done
}

function freeze_directories {
	for volume in "${EBS_VOLUME_MOUNT_POINT_AND_DEVICE_NAMES[@]}"; do
	    local mount_point="$(echo "${volume}" | cut -d ":" -f1)"
		freeze_mount_point "${mount_point}"
	done

    # Add a clean up routine to ensure we always unfreeze the filesystems
    add_cleanup_routine unfreeze_directories
}

function unfreeze_directories {
    remove_cleanup_routine unfreeze_directories

	for volume in "${EBS_VOLUME_MOUNT_POINT_AND_DEVICE_NAMES[@]}"; do
	    local mount_point="$(echo "${volume}" | cut -d ":" -f1)"
        unfreeze_mount_point "${mount_point}"
    done
}

function cleanup_incomplete_disk_backup {
    if (( ${#CREATED_EBS_SNAPSHOTS[@]} )); then
        info "Cleaning up EBS snapshots created as part of failed/incomplete backup"
        for snapshot in "${CREATED_EBS_SNAPSHOTS[@]}"; do
            debug "Deleting EBS snapshot '${snapshot}'"
            run aws ec2 delete-snapshot --snapshot-id "${snapshot}" > /dev/null
        done
    else
        debug "No EBS snapshots to clean up"
    fi
}

function cleanup_old_disk_backups {
    if [ "${KEEP_BACKUPS}" -gt 0 ]; then
        info "Cleaning up any old EBS snapshots and retaining only the most recent ${KEEP_BACKUPS}"
        for volume in "${EBS_VOLUME_MOUNT_POINT_AND_DEVICE_NAMES[@]}"; do
            local device_name="$(echo "${volume}" | cut -d ":" -f2)"
            for ebs_snapshot_id in $(list_old_ebs_snapshot_ids "${AWS_REGION}" "${device_name}"); do
                run aws ec2 delete-snapshot --snapshot-id "${ebs_snapshot_id}" > /dev/null
            done
        done
    fi
}

# ----------------------------------------------------------------------------------------------------------------------
# Disaster recovery functions
# ----------------------------------------------------------------------------------------------------------------------

function promote_home {
    bail "Disaster recovery is not available with this disk strategy"
}

function replicate_disk {
    bail "Disaster recovery is not available with this disk strategy"
}

function setup_disk_replication {
    bail "Disaster recovery is not available with this disk strategy"
}
