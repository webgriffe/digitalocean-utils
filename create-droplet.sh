#!/usr/bin/env bash

# This script requires `doctl` command line utility (https://github.com/digitalocean/doctl).
# This script perform the creation of a single droplet on DigitalOcean.

# exit when any command fails
set -e

# Configuration environment variables

# DNS_ZONE="my-network.com"             # Will be used to set A record to the new droplet for this DNS zone
# DROPLET_SLUG="my-new-droplet"         # The droplet hostname will be "${DROPLET_SLUG}.${DNS_ZONE}"
# DROPLET_IMAGE="ubuntu-18-04-x64"      # Use the command `doctl compute image list-distribution` to list avaliable images
# DROPLET_SIZE="s-4vcpu-8gb"            # Use the command `doctl compute size list` to list avaliable sizes
# DROPLET_REGION="fra1"                 # Use the command `doctl compute region list` to list available regions
# SSH_KEYS=""                           # SSH key fingerprint of who uses this command, use `doctl compute ssh-key list` to list availables SSH keys

# The droplet hostname will be "${DROPLET_SLUG}.${DNS_ZONE}"

# Run

DROPLET_HOSTNAME="${DROPLET_SLUG}.${DNS_ZONE}"
echo "Creating droplet ${DROPLET_HOSTNAME}..."
DROPLET_ID=$(doctl compute droplet create ${DROPLET_HOSTNAME} \
    --size ${DROPLET_SIZE} \
    --image ${DROPLET_IMAGE} \
    --region ${DROPLET_REGION} \
    --ssh-keys ${SSH_KEYS} \
    --format ID \
    --enable-backups \
    --enable-private-networking \
    --no-header \
    --wait)

DROPLET_IP=$(doctl compute droplet get ${DROPLET_ID} --format PublicIPv4 --no-header)
echo "Droplet ${DROPLET_HOSTNAME} created! ID: ${DROPLET_ID}, PublicIPv4: ${DROPLET_IP}"

echo "Waiting 1 minute for a droplet complete boot..."
sleep 60

echo "Adding ${DROPLET_IP} to known hosts..."
ssh-keyscan -H ${DROPLET_IP} >> ~/.ssh/known_hosts

echo "Setting /etc/hostname and rebooting..."
doctl compute ssh ${DROPLET_ID} --ssh-command "echo '${DROPLET_HOSTNAME}' > /etc/hostname"
doctl compute droplet-action reboot ${DROPLET_ID} --wait

echo "Waiting 1 minute for a droplet complete re-boot..."
sleep 60

echo "Installing python-minimal (so it's ready for Ansible)..."
doctl compute ssh ${DROPLET_ID} --ssh-command "apt-get install -y python-minimal"

echo "Setting DNS record for ${DNS_ZONE}..."
doctl compute domain records create ${DNS_ZONE} --record-type A --record-name ${DROPLET_SLUG} --record-data ${DROPLET_IP} --record-ttl 600

echo "Adding ${DROPLET_HOSTNAME} to known hosts..."
ssh-keyscan -H ${DROPLET_HOSTNAME}

# TODO Add floating IP

