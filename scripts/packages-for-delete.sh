#! /bin/bash

SHA_FOR_DELETE=$(\
docker manifest inspect ghcr.io/${ORGANIZATION_NAME}/${COMPONENT_NAME}:${COMPONENT_TAG} \
| jq -r '.manifests | map(.digest) | join("|")')

docker pull ghcr.io/${ORGANIZATION_NAME}/${COMPONENT_NAME}:${COMPONENT_TAG}

REPO_SHA=$(docker inspect ghcr.io/${ORGANIZATION_NAME}/${COMPONENT_NAME}:${COMPONENT_TAG} \
| grep -A 1 RepoDigests | awk 'NR==2{print $1}' | sed 's/.*@//g;s/"//' )


if [ -z "$SHA_FOR_DELETE" ]; then
  if [ -z "$REPO_SHA" ]; then
  echo "No images to delete"
  exit 0
  fi
  SHA_FOR_DELETE=$REPO_SHA
else
  SHA_FOR_DELETE=$SHA_FOR_DELETE\|$REPO_SHA
fi

expectedSum=$(echo $(($(echo ${SHA_FOR_DELETE} | grep -o '|' | grep -c '')+1)))
pageNum=1
while [ $expectedSum -gt 0 ]
do
  foundIds=0
  if [ -z "$IDS_FOR_DELETE" ]; then
    IDS_FOR_DELETE="$( \
    curl -X GET -H "Authorization: Bearer ${ACCESS_TOKEN}" "https://api.github.com/orgs/${ORGANIZATION_NAME}/packages/container/${COMPONENT_NAME}/versions?per_page=100&page=${pageNum}" \
    | grep -E -B 1 "$SHA_FOR_DELETE" | grep id | awk '{print $2}' | sed -z 's/,//g;s/.$//;s/\n/,/g')"
    foundIds=$(echo $(($(echo ${IDS_FOR_DELETE} | grep -o ',' | grep -c '')+1)))
  else
    NEW_IDS_FOR_DELETE=$( \
    curl -X GET -H "Authorization: Bearer ${ACCESS_TOKEN}" "https://api.github.com/orgs/${ORGANIZATION_NAME}/packages/container/${COMPONENT_NAME}/versions?per_page=100&page=${pageNum}" \
    | grep -E -B 1 "$SHA_FOR_DELETE" | grep id | awk '{print $2}' | sed -z 's/,//g;s/.$//;s/\n/,/g')
    if [ ! -z "$NEW_IDS_FOR_DELETE" ]; then
    IDS_FOR_DELETE="${IDS_FOR_DELETE},${NEW_IDS_FOR_DELETE}"
    foundIds=$(echo $(($(echo ${IDS_FOR_DELETE} | grep -o ',' | grep -c '')+1)))
    fi
  fi
  expectedSum=$(($expectedSum-$foundIds))
  pageNum=$(($pageNum+1))
done

echo "IDs for delete: $IDS_FOR_DELETE"

echo "ids-for-delete=${IDS_FOR_DELETE}" >> $GITHUB_OUTPUT
