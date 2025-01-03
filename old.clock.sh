#!/bin/bash

# https://clockify.me/developers-api

 ### first some checks ###
which jq > /dev/null
if [ ! $? -eq 0 ]; then
  echo -e "jq is missing. Try:\nsudo apt-get install jq"
  exit 1
fi

which curl > /dev/null
if [ ! $? -eq 0 ]; then
  echo -e "curl is missing. Try:\nsudo apt-get install curl"
  exit 1
fi



 ### Some functions ###
OLD_IFS=$IFS

if [ x${CLOCKIFY_APIKEY} == x ]; then
  echo "Please export your CLOCKIFY_APIKEY first"
  exit 1
fi

now() {
  date -uIseconds |sed -E "s/^(.{19})(.*$)/\1/g;s/,/./;s/$/Z/"
  # date -uIns|sed -E "s/^(.{23})(.*$)/\1/g;s/,/./;s/$/Z/" # with miliseconds
}

run() {
  curl -s -d "${3}" -H content-type:application/json -H X-Api-Key:${CLOCKIFY_APIKEY} -X $1 https://api.clockify.me/api/v1${2}
}

getWorkspace() {
  run GET /user | jq -Mr ".activeWorkspace"
}

getUserId() {
  run GET /user | jq -Mr '.id'
}

getProjectIdFromWorkspace() {
  IFS=$'\n'
  projectRC=$( run GET /workspaces/${1}/projects )
  select project in $( echo $projectRC | jq -Mr '.[]|.name' ); do break; done
  got=0; for a in $( echo $projectRC | jq -Mr '.[]|.name,.id' ); do
    [ $got -eq 1 ] && echo $a && break;
    [ "$a" == "$project" ] && got=1
  done;
}

getTaskIdFromWorkspaceIDAndProjectID() {
  IFS=$'\n'
  taskRC=$( run GET /workspaces/${1}/projects/${2}/tasks )
  select tasks in $( echo $taskRC | jq -Mr '.[]|.name' ); do break;done
  got=0
  for a in $( echo $taskRC | jq -Mr '.[]|.name,.id' ); do
    [ $got -eq 1 ] && echo $a && break;
    [ "$a" == "$tasks" ] && got=1
  done;
}



 ### running ###
if [ x$1 == xstart ]; then
  workspaceId=$( getWorkspace )
  post_tpl='{"start":"##TIME##"}'
  post=$( echo $post_tpl | sed "s/##TIME##/$(now)/")
  run POST /workspaces/${workspaceId}/time-entries "${post}" | jq '.'
  exit 0
fi

if [ x$1 == xstop ]; then
  workspaceId=$( getWorkspace )
  userId=$( getUserId )
  entry=$( run GET /workspaces/${workspaceId}/user/${userId}/time-entries?in-progress=true )
  entryID=$( echo $entry | jq -Mr '.[].id' )
  starttime=$( echo $entry | jq -Mr '.[]|.timeInterval.start' )
  pID=$( getProjectIdFromWorkspace $workspaceId )
  taskId=$( getTaskIdFromWorkspaceIDAndProjectID $workspaceId $pID )
  read -p "Enter your task description: " description
  post_tpl='{"start":"##STARTTIME##","description": "##DESCRIPTION##","projectId": "##PID##","taskId": "##TASKID##","end": "##STOPTIME##"}'
  post=$( echo $post_tpl | sed "s/##STOPTIME##/$(now)/;s/##STARTTIME##/${starttime}/;s/##DESCRIPTION##/${description}/;s/##PID##/${pID}/;s/##TASKID##/${taskId}/")
  run PUT /workspaces/${workspaceId}/time-entries/${entryID} "${post}" | jq '.'
  exit 0
fi



 ### DEFAULT STDOUT ###
cat<<EOHELP
What is this:
    Extremely simple clockify API implementation

How to use it:
    clock start
         starts the timer
    clock stop
         stops your running timer asking you details of what you did: project, task and description

Version:
    0.1
EOHELP

#IFS=$OLD_IFS
