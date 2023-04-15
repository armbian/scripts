# You need admin:org token capabilities
# NAME = tag you want to delete from all runners
# DELETE = runner you want to delete from the pool

TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ORG=armbian
#NAME=ubuntu-latest
DELETE=thx
x=1
while [ $x -le 9 ]
do
RUNNER=$(
curl -L \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: Bearer $TOKEN"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/orgs/${ORG}/actions/runners?page=${x}" | jq -r '.runners[] | .id, .name' | xargs -n2 -d'\n' | sed -e 's/ /,/g'
)

while IFS= read -r DATA; do
#echo "Line: $RUNNER_ID"
RUNNER_ID=$(echo $DATA | cut -d"," -f1)
RUNNER_NAME=$(echo $DATA | cut -d"," -f2)
echo "Line: $RUNNER_ID $RUNNER_NAME"

# deleting a label
if [[ -n $NAME ]]; then
curl -L \
  -X DELETE \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $TOKEN"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/orgs/${ORG}/actions/runners/${RUNNER_ID}/labels/${NAME}
fi

# deleting a runner
if [[ $RUNNER_NAME == ${DELETE}* ]]; then
curl -L \
  -X DELETE \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${TOKEN}"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/orgs/${ORG}/actions/runners/${RUNNER_ID}
fi

done <<< $RUNNER
x=$(( $x + 1 ))
done
