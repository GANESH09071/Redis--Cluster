#!/bin/bash
set -e


if [ -f "/ansible-keys/id_rsa.pub" ]; then
    cp /ansible-keys/id_rsa.pub /home/ansible/.ssh/authorized_keys
    chown ansible:ansible /home/ansible/.ssh/authorized_keys
    chmod 600 /home/ansible/.ssh/authorized_keys
fi


mkdir -p /run/sshd


exec "$@"
