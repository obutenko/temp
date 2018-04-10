#!/bin/bash -x

set -ex

IRONIC_PXE_MANAGER=${IRONIC_PXE_MANAGER:-'dnsmasq'}  # Options: dnsmasq or neutron
IRONIC_PXE_INTERFACE_NAME=${IRONIC_PXE_INTERFACE_NAME:-'ens7'}
IRONIC_PXE_INTERFACE_ADDRESS=${IRONIC_PXE_INTERFACE_ADDRESS:-'10.0.175.2'}
IRONIC_DHCP_POOL_START=${IRONIC_DHCP_POOL_START:-'10.0.175.100'}
IRONIC_DHCP_POOL_END=${IRONIC_DHCP_POOL_END:-'10.0.175.200'}
IRONIC_DHCP_POOL_NETMASK=${IRONIC_DHCP_POOL_NETMASK:-'255.255.255.0'}
IRONIC_DHCP_POOL_NETMASK_PREFIX=${IRONIC_DHCP_POOL_NETMASK_PREFIX:-'24'}
DNSMASQ_USE_EXTERNAL_DNS=${DNSMASQ_USE_EXTERNAL_DNS:-true}

# Enable keystone for ironic if used with neutron
IRONIC_ENABLE_KEYSTONE=false && [[ "${IRONIC_PXE_MANAGER}" == "neutron" ]] && IRONIC_ENABLE_KEYSTONE=true

# Inverse flag for dnsmasq config
DNSMASQ_DONT_USE_EXTERNAL_DNS=false && [[ "${DNSMASQ_USE_EXTERNAL_DNS}" == false ]] && DNSMASQ_DONT_USE_EXTERNAL_DNS=true

# Install latest salt
wget -O - https://repo.saltstack.com/apt/ubuntu/16.04/amd64/latest/SALTSTACK-GPG-KEY.pub | sudo apt-key add -
sudo echo "deb http://repo.saltstack.com/apt/ubuntu/16.04/amd64/latest xenial main" >  /etc/apt/sources.list.d/saltstack.list

# Install ironic from Newton release
wget -O - http://mirror.fuel-infra.org/mcp-repos/newton/xenial/archive-mcpnewton.key | sudo apt-key add -
sudo echo "deb http://mirror.fuel-infra.org/mcp-repos/newton/xenial newton main" > /etc/apt/sources.list.d/ironic.list

sudo apt-get update
git clone https://github.com/saltstack/salt.git -b v2017.7.4
cd salt
python setup.py install --force

WORKDIR=${WORKDIR:-'/tmp/'}
cd ${WORKDIR}

git clone https://github.com/dis-xcom/underpillar.git
git clone https://review.gerrithub.io/ingwarr/salt-dnsmasq
git clone https://review.gerrithub.io/ingwarr/salt-ironic
git clone https://review.gerrithub.io/ingwarr/salt-tftpd-xinetd
git clone https://review.gerrithub.io/ingwarr/salt-nginx
git clone https://review.gerrithub.io/ingwarr/salt-neutron
git clone https://review.gerrithub.io/ingwarr/salt-keystone
git clone https://github.com/salt-formulas/salt-formula-apache
git clone https://github.com/salt-formulas/salt-formula-memcached
git clone https://github.com/salt-formulas/salt-formula-mysql
git clone https://github.com/salt-formulas/salt-formula-rabbitmq

mkdir -p /srv/pillar/
mkdir -p /srv/salt

cd /srv/salt
ln -s ${WORKDIR}/salt-dnsmasq/dnsmasq
ln -s ${WORKDIR}/salt-formula-apache/apache
ln -s ${WORKDIR}/salt-formula-mysql/mysql
ln -s ${WORKDIR}/salt-formula-rabbitmq/rabbitmq
ln -s ${WORKDIR}/salt-ironic/ironic
ln -s ${WORKDIR}/salt-neutron/neutron
ln -s ${WORKDIR}/salt-tftpd-xinetd/tftpd
ln -s ${WORKDIR}/salt-formula-memcached/memcached
ln -s ${WORKDIR}/salt-keystone/keystone
ln -s ${WORKDIR}/salt-nginx/nginx

cp ${WORKDIR}/underpillar/pillar/*.sls /srv/pillar/
cp ${WORKDIR}/underpillar/states/*.sls /srv/salt/

# Enable Ironic deploy with dnsmasq or neutron
cp /srv/pillar/top_${IRONIC_PXE_MANAGER}.sls /srv/pillar/top.sls
cp /srv/salt/top_${IRONIC_PXE_MANAGER}.sls /srv/salt/top.sls

find /srv/pillar/ -type f -exec sed -i "s/==IRONIC_PXE_INTERFACE_NAME==/${IRONIC_PXE_INTERFACE_NAME}/g" {} +
find /srv/pillar/ -type f -exec sed -i "s/==IRONIC_PXE_INTERFACE_ADDRESS==/${IRONIC_PXE_INTERFACE_ADDRESS}/g" {} +
find /srv/pillar/ -type f -exec sed -i "s/==IRONIC_DHCP_POOL_START==/${IRONIC_DHCP_POOL_START}/g" {} +
find /srv/pillar/ -type f -exec sed -i "s/==IRONIC_DHCP_POOL_END==/${IRONIC_DHCP_POOL_END}/g" {} +
find /srv/pillar/ -type f -exec sed -i "s/==IRONIC_DHCP_POOL_NETMASK==/${IRONIC_DHCP_POOL_NETMASK}/g" {} +
find /srv/pillar/ -type f -exec sed -i "s/==IRONIC_DHCP_POOL_NETMASK_PREFIX==/${IRONIC_DHCP_POOL_NETMASK_PREFIX}/g" {} +
find /srv/pillar/ -type f -exec sed -i "s/==IRONIC_ENABLE_KEYSTONE==/${IRONIC_ENABLE_KEYSTONE}/g" {} +
find /srv/pillar/ -type f -exec sed -i "s/==DNSMASQ_DONT_USE_EXTERNAL_DNS==/${DNSMASQ_DONT_USE_EXTERNAL_DNS}/g" {} +

echo "### Starting Ironic bootstrap, please wait 5-10 min ###"

sudo salt-call --local  --state-output=mixed state.highstate

echo "### Ironic bootstrap completed ###"
