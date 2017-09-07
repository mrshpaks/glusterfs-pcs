#!/bin/bash

######################################################
#
# Installation been done and tested on Centos7 version
#
#####################################################

# Vars source file
source ./setvars

########## FUNCTIONS
# Install packages
install_packages() {
  yum install $@ -y
}

# Services functions
start_services() {
  for i in ${START_LIST}; do
    systemctl restart $i
  done
}
enable_services() {
  for i in ${ENABLE_LIST}; do
    systemctl enable $i
  done
}

# Check root function
check_root() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "Please run this script as root user!"
    exit 1
  fi
}

# Nodes list
get_nodes() {
  grep ${CLUSTER_HOSTNAME} ${HOST_FILE} | awk '{print $2}'
}

# Ping host
check_node() {
  timeout 1 bash -c "cat < /dev/null > /dev/tcp/$1/$2"
}

# Check if all nodes are up
check_nodes() {
  for i in $(get_nodes); do
    check_node $i ${GLUSTER_PORT}
    if [[ "$?" -ne 0 ]]; then
      echo "### Please run this script on all nodes to proceed with configuration!"
      echo "### Exiting..."
      exit 0
    fi
  done
}


########## MAIN
### Cluster installation process
check_root

# Add records to hosts file
NODES_NUMBER=$(echo ${IP_LIST} | wc -w)

if [[ ! $(grep ${CLUSTER_HOSTNAME} ${HOST_FILE}) ]]; then
  echo "### No cluster records found in ${HOST_FILE} file, adding..."
  for i in `seq 1 ${NODES_NUMBER}`; do
    echo "$(echo $IP_LIST | awk "{print \$${i}}") ${CLUSTER_HOSTNAME}${i}" >> ${HOST_FILE}
    done
else
  echo "### Cluster nodes records already exists, please check below..."
  echo "########################## Content of hosts file #############################################"
  cat ${HOST_FILE}
  echo "########################## End of content of hosts file ######################################"
fi

# Install all packages
echo "### Installing cluster packages..."
install_packages centos-release-gluster
install_packages ${PACKAGE_LIST}

# Start and enable services
echo "### Starting and enabling services..."
start_services
enable_services

# Create shared directory
mkdir -p ${CLUSTER_DIR}
chmod -R 777 ${CLUSTER_DIR}

# Set password for hacluster user
echo ${HACLUSTER_PASSWORD} | passwd ${HACLUSTER_USER} --stdin

# Check if all nodes are installed and up
check_nodes

### Cluster configuration process
echo "### Starting cluster configuration..."

# Add nodes to gluster
for i in $(get_nodes); do
  gluster peer probe $i
  sleep 3
done

# Create Gluster volume
REPLICA_SET=$(echo $(get_nodes) | sed "s# #:${CLUSTER_DIR} #g" | sed "s#\$#:${CLUSTER_DIR}#")
gluster volume create ${GLUSTER_VOLUME_NAME} replica ${NODES_NUMBER} ${REPLICA_SET} force

# Start volume and get info
gluster volume start ${GLUSTER_VOLUME_NAME}
echo "########################## Gluster volume info #############################################"
gluster volume info ${GLUSTER_VOLUME_NAME}
echo "########################## End of gluster volume info ######################################"

# Enable nfs on gluster
echo "y" | gluster volume set ${GLUSTER_VOLUME_NAME} nfs.disable off

# PCS cluster config
pcs cluster auth $(get_nodes) -u ${HACLUSTER_USER} -p ${HACLUSTER_PASSWORD} --force
pcs cluster setup --name NFS $(get_nodes) --force
pcs cluster start --all
pcs property set no-quorum-policy=ignore
pcs property set stonith-enabled=false

# PCS configure virtual IP
check_node ${VIRTUAL_IP} 22
if [[ "$?" -eq 0 ]]; then
  echo "### IP address ${VIRTUAL_IP} is already in use, please change it in setvars file!"
  echo "### Exiting..."
  exit 1
fi
pcs resource create virtual_ip ocf:heartbeat:IPaddr2 ip=${VIRTUAL_IP} cidr_netmask=24 op monitor interval=20s

# PCS status
echo "### Waiting for cluster to start..."
sleep 30
echo "########################## PCS cluster status #############################################"
pcs status
echo "########################## End of PCS cluster status ######################################"

### End of installation
echo "### Congratulations!!! Cluster installation is complete!"
echo "### To start using your NFS share, please install nfs-utils and run command below"
echo "### mount -o mountproto=tcp -t nfs ${VIRTUAL_IP}:/${GLUSTER_VOLUME_NAME} /<destination-folder>"
