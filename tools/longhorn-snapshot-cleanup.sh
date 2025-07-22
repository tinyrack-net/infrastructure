#!/bin/bash
set -e

# longhorn backend URL
url=
# By default, snapshot older than 10 days will be deleted
days=10

function display_usage() {
	echo "usage: $(basename "$0") [-h] -u longhorn-url -d days"
	echo "  -u	Longhorn URL"
	echo "  -d 	Number of days(should be >0). By default, script will delete snapshot older than 10 days."
	echo "  -h	Print help"
}

while getopts 'hd:u:' flag "$@"; do
	case "${flag}" in
		u)
			url=${OPTARG}
			;;
		d)
			days=${OPTARG}
			[ "$days" ] && [ -z "${days//[0-9]}" ] || { echo "Invalid number of days=$days"; exit 1; }
			;;
		h)
			display_usage
			exit 0
			;;
		:)
			echo "Invalid option: ${OPTARG} requires an argument."
			exit 1
			;;
		*)
			echo "Unexpected option ${flag}"
			exit 1
			;;
	esac
done

[[ -z "$url" ]] && echo "Missing longhorn URL" && exit 1

# check if URL is valid
curl -s --connect-timeout 30 ${url}/v1 >> /dev/null || { echo "Unable to connect to longhorn backend"; exit 1; }

echo "Deleting snapshots older than $days days"

# Fetch list of longhorn volumes
vols=$( (curl -s -X GET ${url}/v1/volumes |jq -r '.data[].name') )

#delete given snapshot for given volume
function delete_snapshot() {
	local vol=$1
	local snap=$2

	[[ -z "$vol" || -z "$snap" ]] && echo "Error: delete_snapshot: Empty argument" && return 1
	curl -s -X POST ${url}/v1/volumes/${vol}?action=snapshotDelete -d '{"name": "'$snap'"}'
	echo "Snapshot=$snap deleted for volume=$vol"
}

#perform cleanup for given volume
function cleanup_volume() {
	local vol=$1
	local deleted_snap=0

	[[ -z "$vol" ]] && echo "Error: cleanup_volume: Empty argument" && return 1

	# fetch list of snapshot
	snaps=$( (curl -s -X POST ${url}/v1/volumes/${vol}?action=snapshotList | jq  -r '.data[] | select(.usercreated==true) | .name' ) )
	for i in ${snaps[@]}; do
		if [[ $i == "volume-head" ]]; then
			continue
		fi

		# calculate date difference for snapshot
		snapTime=$(curl -s -X POST ${url}/v1/volumes/${vol}?action=snapshotGet -d '{"name":"'$i'"}' |jq -r '.created')
		currentTime=$(date "+%s")
		timeDiff=$(($currentTime - ($(date -d $snapTime "+%s")) / 86400))
		if [[ $timeDiff -lt $days ]]; then
			echo "Ignoring snapshot $i, since it is older than $timeDiff days"
			continue
		fi

		#trigger deletion for snapshot
		delete_snapshot $vol $i
		deleted_snap=$((deleted_snap+1))
	done

	if [[ "$deleted_snap" -gt 0 ]]; then
		#trigger purge for volume
		curl -s -X POST ${url}/v1/volumes/${vol}?action=snapshotPurge >> /dev/null
	fi

}

for i in ${vols[@]}; do
	cleanup_volume $i
done