# You need admin:org token capabilities
# NAME = tag you want to delete from all runners
# DELETE = runner you want to delete from the pool

TOKEN=
ORG="orgs/armbian"
#ORG="user"
x=1
while [ $x -le 51 ] # need to do it different as it can be more then 9 pages
do
RUNNER=$(
curl -L \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: Bearer $TOKEN"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/${ORG}/packages?package_type=container&page=${x}" | jq -r '.[].name' | xargs -n1 -d'\n' | sed 's/\//%2F/g' | sed -e 's/ /,/g'
)

while IFS= read -r DATA; do

RUNNER_ID=$(echo $DATA | cut -d"," -f1)
#RUNNER_NAME=$(echo $DATA | cut -d"," -f2)
echo $RUNNER_ID
if [[ $RUNNER_ID == cache* ]]; then
echo "PKG to remove: $RUNNER_ID"
curl -L \
  -X DELETE \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $TOKEN"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/${ORG}/packages/container/${RUNNER_ID}"
fi

done <<< $RUNNER
x=$(( $x + 1 ))
done
