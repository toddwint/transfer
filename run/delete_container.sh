#!/usr/bin/env bash
SCRIPTDIR="$(dirname "$(realpath "$0")")"

# Check that files exist first
FILES=(".env")
for FILE in "${FILES[@]}"; do
    if [ ! -f "${SCRIPTDIR}/${FILE}" ]; then
            echo "File not found: ${FILE}"
            echo "Run create_container.sh first."
            exit 1
    fi
done

# Then start by importing environment file
source "${SCRIPTDIR}"/.env

# Stop and remove the container
echo "Stopping and removing the container: ${HOSTNAME}"
docker container stop "${HOSTNAME}"
docker container rm "${HOSTNAME}"

# Remove the docker networking interface
echo '- - - - -'
echo "Removing docker network: ${HOSTNAME}"
docker network rm "${HOSTNAME}"

# test if previous command ran without errors
RC=$?
if [ ! ${RC} -eq 0 ]; then exit; fi

# Remove the management networking interface
echo "Removing management network: ${HOSTNAME::15}@${INTERFACE}"
sudo ip link del "${HOSTNAME::15}"

# Remove the webadmin.html customized files
echo '- - - - -'
echo -e "Removing webadmin file: webadmin.html"
rm -rf "${SCRIPTDIR}"/webadmin.html

# Remove the .env file
echo -e "Removing environment file: .env"
rm -rf "${SCRIPTDIR}"/.env
