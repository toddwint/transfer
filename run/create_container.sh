#!/usr/bin/env bash
SCRIPTDIR="$(dirname "$(realpath "$0")")"

# Check that files exist first
FILES=("config.txt" "templates/webadmin.html.template")
for FILE in "${FILES[@]}"; do
    if [ ! -f "${SCRIPTDIR}/${FILE}" ]; then
            echo "File not found: ${FILE}"
            echo "Cannot continue. Exiting script."
            exit 1
    fi
done

# Then start by importing environment file
source "${SCRIPTDIR}"/config.txt

# Copy config.txt to .env
echo "Creating container: ${HOSTNAME}"
cp "${SCRIPTDIR}/config.txt" "${SCRIPTDIR}/.env"
echo "Copied config.txt to .env"

# Get the User ID and Group ID.
HUID=$(id -u)
HGID=$(id -g)
echo "User id: ${HUID}, Group id: ${HGID}"
USERINFO="""
# Current user id
HUID=${HUID}

# Current group id
HGID=${HGID}
"""

# Add User and Group IDs to env variables
echo "Adding User ID and Group ID to .env"
echo -e "${USERINFO}" >> "${SCRIPTDIR}/.env"

# Create the docker network and management macvlan interface
echo '- - - - -'
echo "Creating docker network: ${HOSTNAME}"
docker network create -d macvlan --subnet=${SUBNET} --gateway=${GATEWAY} \
    --aux-address="mgmt_ip=${MGMTIP}" -o parent="${INTERFACE}" \
    --attachable "${HOSTNAME}"
echo "Creating management network: ${HOSTNAME::15}@${INTERFACE}"
sudo ip link add "${HOSTNAME::15}" link "${INTERFACE}" type macvlan mode bridge
sudo ip link set "${HOSTNAME::15}" up
sudo ip addr add "${MGMTIP}/32" dev "${HOSTNAME::15}"
sudo ip route add "${SUBNET}" dev "${HOSTNAME::15}"
echo "Added routes from management network to docker network"

# Create the docker container
echo '- - - - -'
echo "Starting container: ${HOSTNAME}"
docker run -dit \
    --name "${HOSTNAME}" \
    --network "${HOSTNAME}" \
    --ip "${IPADDR}" \
    -h "${HOSTNAME}" \
    ` # Volume can be changed to another folder. For Example: ` \
    ` # -v "/home/${USER}/Desktop/public:/opt/${APPNAME}/public" \ ` \
    -v "${SCRIPTDIR}/public:/opt/${APPNAME}/public" \
    -p "${IPADDR}:80:80" \
    -p "${IPADDR}:${HTTPPORT1}:${HTTPPORT1}" \
    -p "${IPADDR}:${HTTPPORT2}:${HTTPPORT2}" \
    -p "${IPADDR}:${HTTPPORT3}:${HTTPPORT3}" \
    -p "${IPADDR}:${HTTPPORT4}:${HTTPPORT4}" \
    -e TZ="${TZ}" \
    -e MGMTIP="${MGMTIP}" \
    -e GATEWAY="${GATEWAY}" \
    -e HUID="${HUID}" \
    -e HGID="${HGID}" \
    -e ENABLE_DHCP="${ENABLE_DHCP}" \
    -e ENABLE_HTTP="${ENABLE_HTTP}" \
    -e ENABLE_TFTP="${ENABLE_TFTP}" \
    -e ENABLE_FTP="${ENABLE_FTP}" \
    -e HTTPPORT1="${HTTPPORT1}" \
    -e HTTPPORT2="${HTTPPORT2}" \
    -e HTTPPORT3="${HTTPPORT3}" \
    -e HTTPPORT4="${HTTPPORT4}" \
    -e HOSTNAME="${HOSTNAME}" \
    -e APPNAME="${APPNAME}" \
    `# --cap-add=NET_ADMIN \ ` \
    "toddwint/${APPNAME}"

# Create the webadmin html file from template
echo '- - - - -'
HTMLTEMPLATE="${SCRIPTDIR}"/templates/webadmin.html.template
HTMLFILE="${SCRIPTDIR}"/webadmin.html
cp "${HTMLTEMPLATE}" "${HTMLFILE}"
sed -Ei 's/hostname/'"${HOSTNAME}"'/gi' "${HTMLFILE}"
sed -Ei 's/\bIPADDR:HTTPPORT1\b/'"${IPADDR}"':'"${HTTPPORT1}"'/g' "${HTMLFILE}"
sed -Ei 's/\bIPADDR:HTTPPORT2\b/'"${IPADDR}"':'"${HTTPPORT2}"'/g' "${HTMLFILE}"
sed -Ei 's/\bIPADDR:HTTPPORT3\b/'"${IPADDR}"':'"${HTTPPORT3}"'/g' "${HTMLFILE}"
sed -Ei 's/\bIPADDR:HTTPPORT4\b/'"${IPADDR}"':'"${HTTPPORT4}"'/g' "${HTMLFILE}"
sed -Ei 's/\bIPADDR:80\b/'"${IPADDR}"':80/g' "${HTMLFILE}"
echo "Added file: webadmin.html"

## Give the user instructions and offer to launch webadmin page
echo '- - - - -'
echo -e "Open the following file to manage this project: webadmin.html"
read -rp 'Would you like to open that file now? [Y/n]: ' ANSWER
if [ -z ${ANSWER} ]; then ANSWER='y'; fi
if [[ ${ANSWER,,} =~ ^y ]]
then
    firefox "${SCRIPTDIR}/webadmin.html" > /dev/null 2>&1 &
fi
