CFG_URL=${1-https://dist.plone.org/release/5.1.7/versions.cfg}
OUT_NAME="$(echo ${CFG_URL} | sed 's/\W/./g')"
mkdir -p cfgs/

echo $CFG_URL "${OUT_NAME}" 1>&2
curl -sL "${CFG_URL}" > "cfgs/${OUT_NAME}"

for SUB_URL in $(grep -oE 'https?://.*\.cfg' "cfgs/${OUT_NAME}"); do
    SUB_OUT_NAME="$($0 "${SUB_URL}")"
    sed -i "s|${SUB_URL}|${SUB_OUT_NAME}|" "cfgs/${OUT_NAME}"
done
echo "${OUT_NAME}"
