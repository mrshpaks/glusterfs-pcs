# Glusterfs + NFS + PCS installation script

## This script installs GlusterFS with NFS support and enabling virtual IP via PCS

This is my first project on github. It was inspired by [this blog post](https://jamesnbr.wordpress.com/2017/01/26/glusterfs-and-nfs-with-high-availability-on-centos-7/) and I want to thanks blog author for this.

## Before you begin
The script has been tested on **CentOS 7** running in VirtualBox

Please edit file [setvars](setvars) and set your own values for variables
  1. A list of IP addresses of your cluster
  ```
  IP_LIST
  ```

  2. Preferable hostnames for your cluster
  ```
  CLUSTER_HOSTNAME
  ```

  3. PCS virtual IP to be used during installation, this IP must **not be in use** by any other host and has to be in **the same subnet** as your cluster nodes
  ```
  VIRTUAL_IP
  ```

  4. Choose a directory for your NFS share
  ```
  NFS_DIR
  ```

  5. Set volume name for GlusterFS if needed
  ```
  GLUSTER_VOLUME_NAME
  ```

  6. Set the password for hacluster user (user account will be created automaticaly during pcs package insyallation)
  ```
  HACLUSTER_PASSWORD
  ```
  7. You can edit or add values to another variables if needed

## Installation

Run the script on each node. Enjoy!
