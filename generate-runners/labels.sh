# this utility adds or remove ARM64 tag to specific runners
# will be deprecated soon

GH_TOKEN=
ACTION=add
-------------------------------------------------------------------------------------
PATTERN=("threadripper" "ryzen" "gaming" "xogium-ryzen" "werner-x64" "xogium-ryzen")
for SEARCH in "${PATTERN[@]}"
do
x=1
while [ $x -le 3 ]
do

RUNNERS=$(gh api \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "/orgs/armbian/actions/runners?per_page=100&page=${x}" | \
        jq -r '.runners[] | select(.name|startswith("'$SEARCH'"))'  | jq '.id')

# main loop
while IFS= read -r id; do

if [[ $ACTION == delete ]]; then

		gh api --silent \
			  --method DELETE \
			  -H "Accept: application/vnd.github+json" \
			  -H "X-GitHub-Api-Version: 2022-11-28" \
			  /orgs/armbian/actions/runners/${id}/labels/ARM64 2> /dev/null
fi

if [[ $ACTION == add ]]; then
curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GH_TOKEN"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/orgs/armbian/actions/runners/${id}/labels \
  -d '{"labels":["ARM64"]}'
fi

echo "Action $ACTION id: $id"

done <<< $RUNNERS

  x=$(( $x + 1 ))
done
done

