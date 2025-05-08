FROM ubuntu:22.04

RUN set -eux; \
    # apt install
    sed -i 's/archive.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list; \
    apt-get update; \
    # Install OpenSSH for MPI to communicate between containers
    apt-get install -y --no-install-recommends \
	openssh-client \
	openssh-server \
	pdsh \
	net-tools \
        iputils-ping \
        iproute2 \
        procps \
        ca-certificates \
        netcat \
        curl \
        less; \
    mkdir -p /var/run/sshd; \
    # Allow OpenSSH to talk to containers without asking for confirmation
    # by disabling StrictHostKeyChecking.
    # mpi-operator mounts the .ssh folder from a Secret. For that to work, we need
    # to disable UserKnownHostsFile to avoid write permissions.
    # Disabling StrictModes avoids directory and files read permission checks.
    sed -i 's/[ #]\(.*StrictHostKeyChecking \).*/ \1no/g' /etc/ssh/ssh_config; \
    echo "    UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config; \
    sed -i 's/#\(StrictModes \).*/\1no/g' /etc/ssh/sshd_config; \
    # clean apt cache
    rm -rf /var/lib/apt/lists/*

WORKDIR /root