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
	curl --silent \
		--request "${METHOD}" \
		--header "X-Api-Key: ${CLOCKIFY_APIKEY}" \
		--header "Content-Type: application/json" \
		--data "$3" \
		${URL}${ACTION}
}

parse_menu () {
	local IN=$(cat)
	local OFS=$IFS
	local IFS=$'\n'
	local options=""
	for entry in $IN; do
		entry=$(sed "s/'/\'/g;s/ /⠀/g" <<<$entry) # this is not an space
		options="${options} ${entry}" 
	done
	IFS=$OFS
	dialog --no-cancel --output-fd 1 --menu "$1" 11 $WIDTH 11 $options
}

workspace=$(call GET "/v1/workspaces" | jq -Mr ".[]|.id,.name" | parse_menu "Workspace")
project=$(call GET "/v1/workspaces/${workspace}/projects" | jq -Mr ".[]|.id,.name" | parse_menu "Project") 

doExit=0
while [[ "${doExit}" == "0" ]]; do
	action=$(dialog --no-items --no-cancel --output-fd 1 --menu "Action" 15 $WIDTH 15 "Add task" "Start" "Stop" "Exit")
	case ${action} in
		"Add task")
			task_name=$(dialog --no-cancel --output-fd 1 --inputbox "Task name" 8 $WIDTH)
			payload=$(jq -Mcn --arg name "${task_name}" '{name: $name, status: "ACTIVE"}')
			call POST "/v1/workspaces/${workspace}/projects/${project}/tasks" "$payload"
			dialog --msgbox "Task creation request sent" 6 35
		;;
		"Start")
			task=$(call GET "/v1/workspaces/${workspace}/projects/${project}/tasks" | jq -Mr ".[]|.id,.name" | parse_menu "Task")
			description=$(dialog --no-cancel --output-fd 1 --inputbox "Time entry description" 8 $WIDTH)
			starttime=$(TZ=GMT date +%Y-%m-%dT%H:%M:%SZ)
			payload=$(jq -Mcn --arg description "${description}" --arg project "${project}" --arg starttime "${starttime}" --arg task "${task}" \
				'{description: $description, projectId: $project, start: $starttime, taskId: $task}' \
			)
			call POST "/v1/workspaces/${workspace}/time-entries" "$payload"
		;;
		"Stop")
			echo not yet; read
		;;
		"Exit")
			dialog --output-fd 1 --yesno "Are you sure?" 5 25
			if [[ "$?" == "0" ]]; then
				doExit=1
			fi
		;;
	esac
done



