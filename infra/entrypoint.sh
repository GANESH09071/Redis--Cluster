#!/bin/bash
set -e

# If a public key is mounted/provided, add it to authorized_keys
if [ -f "/ansible-keys/id_rsa.pub" ]; then
    cp /ansible-keys/id_rsa.pub /home/ansible/.ssh/authorized_keys
    chown ansible:ansible /home/ansible/.ssh/authorized_keys
    chmod 600 /home/ansible/.ssh/authorized_keys
fi

# Make sure /run/sshd exists
mkdir -p /run/sshd

# Execute the main command
exec "$@"
