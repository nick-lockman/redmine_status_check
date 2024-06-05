#!/bin/sh

export LANG=ru_RU.UTF-8

CURL=/usr/bin/curl
DATE=/usr/bin/date       
TODAY=`${DATE} +%Y-%m-%d`
SCRIPT_NAME=$(basename "$0")
CONF_PATH=/usr/local/scripts/${SCRIPT_NAME%.*}/${SCRIPT_NAME%.*}.conf

if test -f ${CONF_PATH} ; then
  . ${CONF_PATH} ; else
  echo 'Error: no .conf file. Exit!' && exit 1
fi

redmine_status_from_id=$(${CURL} -X GET -G ${ISSUE_STATUS_URL} \
        -H "Content-type: application/json" \
        -u ${API_KEY}: \
        | jq --arg status_from "${STATUS_FROM}" \
        '.issue_statuses | map(select(.name==$status_from))[0].id | select( . != null )')

echo ${redmine_status_from_id}
[ -z ${redmine_status_from_id} ] && echo "`date`: error: status from not found" >> ${LOG_PATH} && exit 1

redmine_status_to_id=$(${CURL} -X GET -G ${ISSUE_STATUS_URL} \
        -H "Content-type: application/json" \
        -u ${API_KEY}: \
        | jq --arg status_to "${STATUS_TO}" \
        '.issue_statuses | map(select(.name==$status_to))[0].id | select( . != null )')

echo ${redmine_status_to_id}
[ -z ${redmine_status_to_id} ] && echo "`date`: error: status to not found" >> ${LOG_PATH} && exit 1

redmine_issue_ids=$(${CURL} -X GET -G ${ISSUE_URL} \
        -H "Content-type: application/json" \
        -d c[]="status" \
        -d c[]="start_date" \
        -d f[]="status_id" \
        -d f[]="start_date" \
        -d op["status_id"]="=" \
        -d op["start_date"]=%3C%3D \
        -d v["status_id"][]=${redmine_status_from_id} \
        -d v["start_date"][]=${TODAY} \
        -u ${API_KEY}: \
        | jq '.issues[].id') 

[ -z ${redmine_issue_ids} ] && echo "`date`: not issues to update" >> ${LOG_PATH} && exit 0

issue_update_params=$(jq --null-input \
                         --arg status_to "${redmine_status_to_id}" \
                         '{"issue":{"status_id": $status_to}}')

for i in ${redmine_issue_ids} ; do
        ${CURL} -v -X PUT "${REDMINE_URL}/issues/${i}.json" \
               -H "Content-type: application/json" \
               --data "${issue_update_params}" \
               -u ${API_KEY}: \
        && echo "`date`: update status on ${REDMINE_URL}/issues/${i}" >> ${LOG_PATH} \
        && ${CURL} -v -H "Connection: close" "${REDMINE_URL}/issues/${i}.json" > /dev/null
done

exit 0