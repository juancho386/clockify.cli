#!/bin/bash
requeriments="curl jq sed dialog"
for requeriment in $requeriments; do
	which $requeriment >/dev/null
	if [[ "$?" != "0" ]]; then
		echo "Error: $requeriment not found. Exiting."
		exit 1
	fi
done

source ./config.ini


call () {
	local METHOD=$1
	local ACTION=$2
	local URL='https://api.clockify.me/api'
	curl -s --request "${METHOD}" --header "X-Api-Key: ${CLOCKIFY_APIKEY}" ${URL}${ACTION}
}

parse_menu () {
	local IN=$(cat)
	local OFS=$IFS
	local IFS=$'\n'
	local options=""
	for entry in $IN; do
		entry=$(sed "s/[']/\'/g;s/ /_/g" <<<$entry)
		options="${options} ${entry}" 
	done
	IFS=$OFS
	dialog --output-fd 1 --menu "$1" 11 70 11 $options
}

workspace=$(call GET "/v1/workspaces" | jq -Mr ".[]|.id,.name" | parse_menu "Workspace")
project=$(call GET "/v1/workspaces/${workspace}/projects" | jq -Mr ".[]|.id,.name" | parse_menu "Project") 
echo $project
