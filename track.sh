#!/bin/bash
requeriments="curl jq"
for requeriment in $requeriments; do
	which $requeriment >/dev/null
	if [[ "$?" != "0" ]]; then
		echo "Error: $requeriment not found. Exiting."
		exit 1
	fi
done

source ./config.ini


call () {
	METHOD=$1
	ACTION=$2
	URL='https://api.clockify.me/api'
	curl -s --request "${METHOD}" --header "X-Api-Key: ${CLOCKIFY_APIKEY}" ${URL}${ACTION}
}

call GET "/v1/workspaces" | jq
