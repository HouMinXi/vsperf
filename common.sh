#!/bin/bash
CASE_PATH="/mnt/tests/kernel/networking/vsperf/vsperf_CI"
source ${CASE_PATH}/env.sh
. /etc/os-release
set -x

get_nic_info(){
	echo "check network card"
	ip link show
	NIC1_PCI_ADDR=`ethtool -i $NIC1 | grep -Eo '[0-9]+:[A-Za-z0-9]+:[0-9]+\.[0-9]+'`
	NIC2_PCI_ADDR=`ethtool -i $NIC2 | grep -Eo '[0-9]+:[A-Za-z0-9]+:[0-9]+\.[0-9]+'`
	NICNUMA=`cat /sys/class/net/$NIC1/device/numa_node`
	echo 'NICNUMA="'${NICNUMA}'"' >>  ${CASE_PATH}/nic_info.conf
	echo 'NIC1_PCI_ADDR="'${NIC1_PCI_ADDR}'"' >> ${CASE_PATH}/nic_info.conf
	echo 'NIC2_PCI_ADDR="'${NIC2_PCI_ADDR}'"' >> ${CASE_PATH}/nic_info.conf	
}

bug1378586_workaround(){
        if [ "$1" == "ovsvanilla" ];then
                \cp ${CASE_PATH}/beaker_ci_conf/vswitch_controller_pxp_vanilla.py /root/vswitchperf/core/vswitch_controller_pxp.py
        fi
        if [ "$1" == "ovsdpdkvhost" ];then
                \cp ${CASE_PATH}/beaker_ci_conf/vswitch_controller_pxp_dpdk.py /root/vswitchperf/core/vswitch_controller_pxp.py
                \cp ${CASE_PATH}/beaker_ci_conf/ovs_dpdk_vhost.py /root/vswitchperf/vswitches/ovs_dpdk_vhost.py
        fi
}

ixgbe_patch(){
	#because rhel7.6, the ixgbe nic need to configure mac before sriov testing
	\cp ${CASE_PATH}/beaker_ci_conf/qemu_pci_passthrough_ixgbe.py /root/vswitchperf/vnfs/qemu/qemu_pci_passthrough.py
}

qede_patch_sriov(){
        #because qede has no mac after create vf, the qede nic need to configure trust on after sriov testing
        \cp ${CASE_PATH}/beaker_ci_conf/qemu_pci_passthrough_qede.py /root/vswitchperf/vnfs/qemu/qemu_pci_passthrough.py
	
}


mlx_patch(){
	\cp ${CASE_PATH}/beaker_ci_conf/networkcard_mlx5.py /root/vswitchperf/tools/networkcard.py
	\cp ${CASE_PATH}/beaker_ci_conf/ovs_dpdk_vhost_mlx5.py /root/vswitchperf/vswitches/ovs_dpdk_vhost.py
	\cp ${CASE_PATH}/beaker_ci_conf/dpdk_mlx5.py /root/vswitchperf/src/dpdk/dpdk.py
	\cp ${CASE_PATH}/beaker_ci_conf/ovs_vanilla_mlx5.py /root/vswitchperf/vswitches/ovs_vanilla.py
	\cp ${CASE_PATH}/beaker_ci_conf/qemu_pci_passthrough_mlx5.py /root/vswitchperf/vnfs/qemu/qemu_pci_passthrough.py
}

mlx_patch_sriov(){
	dpdk_version=`rpm -qa dpdk|awk -F '-' '{printf $2}' |awk -F '.' '{printf $1}'`
	if [ $dpdk_version -ge 20 ];then
		\cp ${CASE_PATH}/beaker_ci_conf/qemu_mlx_sriov_20.py /root/vswitchperf/vnfs/qemu/qemu.py
	else
		\cp ${CASE_PATH}/beaker_ci_conf/qemu_mlx_sriov.py /root/vswitchperf/vnfs/qemu/qemu.py
	fi
}

bnxt_patch(){
        dpdk_version=`rpm -qa dpdk|awk -F '-' '{printf $2}' |awk -F '.' '{printf $1}'`
        if [ $dpdk_version -ge 20 ];then
		\cp ${CASE_PATH}/beaker_ci_conf/qemu_bnxt_sriov_20.py /root/vswitchperf/vnfs/qemu/qemu.py
	else
		\cp ${CASE_PATH}/beaker_ci_conf/qemu_bnxt_sriov.py /root/vswitchperf/vnfs/qemu/qemu.py
	fi
}

nfp_patch(){
	sed -i "s/OVS_USER_ID/#OVS_USER_ID/g" /etc/sysconfig/openvswitch
	\cp ${CASE_PATH}/beaker_ci_conf/ovs_dpdk_vhost_nfp.py /root/vswitchperf/vswitches/ovs_dpdk_vhost.py
}

mlx4_patch1()
{
        yum install -y libibverbs
        echo options mlx4_core log_num_mgm_entry_size=-1  >> /etc/modprobe.d/mlx4.conf
        dracut -f -v
}

mlx4_patch2(){
        \cp ${CASE_PATH}/beaker_ci_conf/ovs_dpdk_vhost_mlx4.py /root/vswitchperf/vswitches/ovs_dpdk_vhost.py
	\cp ${CASE_PATH}/beaker_ci_conf/networkcard_mlx5.py /root/vswitchperf/tools/networkcard.py
	\cp ${CASE_PATH}/beaker_ci_conf/dpdk_mlx5.py /root/vswitchperf/src/dpdk/dpdk.py
	\cp ${CASE_PATH}/beaker_ci_conf/ovs_vanilla_mlx5.py /root/vswitchperf/vswitches/ovs_vanilla.py
	\cp ${CASE_PATH}/beaker_ci_conf/qemu_pci_passthrough_mlx5.py /root/vswitchperf/vnfs/qemu/qemu_pci_passthrough.py
}

qede_patch()
{
	if [ "$QCOW_LOC" == "China" ]
	then
    		SERVER="netqe-bj.usersys.redhat.com/share/tli/vsperf_img"
	elif [ "$QCOW_LOC" == "Westford" ]
    	then
    		SERVER="netqe-infra01.knqe.lab.eng.bos.redhat.com/vm"
	fi
        wget -P /usr/lib/firmware/qed/ $SERVER/qed_init_values-8.40.33.0.bin
}

n3000_patch()
{
	wget -P /root/ http://netqe-bj.usersys.redhat.com/share/tli/n3000/n3000_ias_1_3_1_pv_rte_RHEL_installer.tar.gz
	yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
	yum install epel-release -y
	yum install gcc gcc-c++ cmake make autoconf automake libxml2 libxml2-devel json-c-devel boost ncurses ncurses-devel ncurses-libs boost-devel libuuid libuuid-devel python2-jsonschema doxygen hwloc-devel libpng12 rsync openssl-devel bc python-devel python-libs python-sphinx openssl python2-pip python3 -y 
	yum install python3-devel python3-libs python3-sphinx python3-jsonschema -y
	pushd /root/
        tar xzvf n3000_ias_1_3_1_pv_rte_RHEL_installer.tar.gz
	pushd n3000_ias_1_3_1_pv_rte_RHEL_installer
	sh n3000-1.3.8-3-rte-el8-setup.sh
expect -c "
    spawn sh n3000-1.3.8-3-rte-el8-setup.sh
    expect \"Do you wish to install OPAE Software\"
    send \"y\n\r\"
    expect \"Do you wish to install OPAE PACSign\"
    send \"y\n\r\"
    expect \"Do you wish to install OPAE SDK Source\"
    send \"y\n\r\"
    expect \"Do you wish to install OPAE Driver Source RPM\"
    send \"y\n\r\"
    expect \"Do you wish to install OPAE Admin Source\"
    send \"y\n\r\"
    expect \"Do you wish to install OPAE PACSign Source\"
    send \"y\n\r\"
    expect \"o you wish to install OPAE Software Samples\"
    send \"y\n\r\"
    expect \"Do you wish to install N3000 A10 Image\"
    send \"y\n\r\"
    expect \"Do you wish to install Environment Initialization\"
    send \"y\n\r\"
    expect \"Analyzing dependencies\"
    send \"\n\r\"
    expect \"Is this ok\"
    send \"y\n\r\"
    expect \"Is this ok\"
    send \"y\n\r\"
    expect \"Is this ok\"
    send \"y\n\r\"
    expect eof
"
	source /root/intelrtestack/bin/init_env.sh
        popd
	fpgainfo phy
}

enable_ovs_debug(){
	\cp ${CASE_PATH}/beaker_ci_conf/ofctl_debug.py /root/vswitchperf/src/ovs/ofctl.py
}

disable_ovs_debug(){
	\cp ${CASE_PATH}/beaker_ci_conf/ofctl.py /root/vswitchperf/src/ovs/ofctl.py
}

install_selinux_policy(){
	# specifying a default container_selinux_policy_rpm here which can be overwritten in recipe XML
	container_selinux_policy_rpm=${container_selinux_policy_rpm:-"http://download-node-02.eng.bos.redhat.com/brewroot/packages/container-selinux/2.77/1.el7_6/noarch/container-selinux-2.77-1.el7_6.noarch.rpm"}
	yum install -y policycoreutils-python
	yum install -y ${container_selinux_policy_rpm}
	yum install -y ${selinux_policy_rpm}
}

run_nightly_report() {
   pushd ${CASE_PATH}/report
   /usr/bin/python2 last_nightly.py
   popd
}



run_weekly_report() {
   pushd ${CASE_PATH}/report
   /usr/bin/python2 last_weekly.py
   popd
}

run_gating_report() {
   pushd ${CASE_PATH}/report
   /usr/bin/python2 last_gating.py
   popd
}

install_driverctl() {
yum install -y http://download-node-02.eng.bos.redhat.com/brewroot/packages/driverctl/0.95/1.el7fdparch/noarch/driverctl-0.95-1.el7fdparch.noarch.rpm
}

change_to_driverctl(){
    \cp ${CASE_PATH}/beaker_ci_conf/dpdk_driverctl.py /root/vswitchperf/src/dpdk/dpdk.py
}

modify_testcase(){
        \cp $CASE_PATH/beaker_ci_conf/01_testcases.conf /root/vswitchperf/conf/01_testcases.conf
}

modify_latency_test(){
	#modify some vsperf file to make can run 50% throughput latency case
	\cp $CASE_PATH/beaker_ci_conf/xena.py /root/vswitchperf/tools/pkt_gen/xena/xena.py
	\cp $CASE_PATH/beaker_ci_conf/xena_json.py /root/vswitchperf/tools/pkt_gen/xena/json/xena_json.py
	\cp $CASE_PATH/beaker_ci_conf/traffic_controller_rfc2544.py /root/vswitchperf/core/traffic_controller_rfc2544.py
	\cp $CASE_PATH/beaker_ci_conf/trafficgen.py /root/vswitchperf/tools/pkt_gen/trafficgen/trafficgen.py
	\cp $CASE_PATH/beaker_ci_conf/trex.py /root/vswitchperf/tools/pkt_gen/trex/trex.py
}

move_result() {
        local folder_name=$1
        mkdir /tmp/${folder_name}
        mv /tmp/result* /tmp/${folder_name}/
        mv /tmp/pmd.log /tmp/${folder_name}/
}

Activate_Python3() {
	#active the python env to python3	
	#scl enable python33 bash
	. /etc/os-release
	if (($(bc <<< "$VERSION_ID < 8"))); then
        	source /root/vsperfenv/bin/activate
	fi
}

:<<block
modify_qemu_file_enable_viommu() {
    \cp ${CASE_PATH}/beaker_ci_conf/qemu_${guest_dpdk_version}_viommu.py /root/vswitchperf/vnfs/qemu/qemu.py
}

modify_qemu_file_disable_viommu() {
    \cp ${CASE_PATH}/beaker_ci_conf/qemu_${guest_dpdk_version}.py /root/vswitchperf/vnfs/qemu/qemu.py
}

modify_qemu_file_testpmd_as_switch() {
    \cp ${CASE_PATH}/beaker_ci_conf/qemu_testpmd_as_switch_${guest_dpdk_version}.py /root/vswitchperf/vnfs/qemu/qemu.py
}
block

modify_qemu_file_enable_viommu() {
    if [ "$QEMU_VER" == "OSP8" ] || [ "$QEMU_VER" == "29" ] || [ "$QEMU_VER" == "210" ];then
	    \cp ${CASE_PATH}/beaker_ci_conf/qemu_viommu_old.py /root/vswitchperf/vnfs/qemu/qemu.py
    else
	dpdk_version=`rpm -qa dpdk|awk -F '-' '{printf $2}' |awk -F '.' '{printf $1}'`
	if [ $dpdk_version -ge 20 ];then
	    \cp ${CASE_PATH}/beaker_ci_conf/qemu_viommu_20.py /root/vswitchperf/vnfs/qemu/qemu.py
	     \cp ${CASE_PATH}/beaker_ci_conf/systeminfo.py /root/vswitchperf/tools/systeminfo.py
        else
            \cp ${CASE_PATH}/beaker_ci_conf/qemu_viommu.py /root/vswitchperf/vnfs/qemu/qemu.py
	fi	
    fi
}

modify_qemu_file_disable_viommu() {
    if [ "$QEMU_VER" == "OSP8" ] || [ "$QEMU_VER" == "29" ] || [ "$QEMU_VER" == "210" ];then
            \cp ${CASE_PATH}/beaker_ci_conf/qemu_old.py /root/vswitchperf/vnfs/qemu/qemu.py
    else
	dpdk_version=`rpm -qa dpdk|awk -F '-' '{printf $2}' |awk -F '.' '{printf $1}'`
        if [ $dpdk_version -ge 20 ];then
            \cp ${CASE_PATH}/beaker_ci_conf/qemu_20.py /root/vswitchperf/vnfs/qemu/qemu.py
	    \cp ${CASE_PATH}/beaker_ci_conf/systeminfo.py /root/vswitchperf/tools/systeminfo.py 
	else
	    \cp ${CASE_PATH}/beaker_ci_conf/qemu.py /root/vswitchperf/vnfs/qemu/qemu.py
	fi
    fi
}


modify_qemu_file_testpmd_as_switch() {
   dpdk_version=`rpm -qa dpdk|awk -F '-' '{printf $2}' |awk -F '.' '{printf $1}'`
   if [ $dpdk_version -ge 20 ];then
	\cp ${CASE_PATH}/beaker_ci_conf/qemu_testpmd_as_switch_20.py /root/vswitchperf/vnfs/qemu/qemu.py
   else
   	 \cp ${CASE_PATH}/beaker_ci_conf/qemu_testpmd_as_switch.py /root/vswitchperf/vnfs/qemu/qemu.py
   fi
}

modify_enable_mergable_buffers(){
echo -e "GUEST_NIC_MERGE_BUFFERS_DISABLE = [False]" >> /root/vswitchperf/conf/10_custom.conf
}

copy_vswitch_vanilla()
{
\cp $CASE_PATH/beaker_ci_conf/02_vswitch_vanilla.conf /root/vswitchperf/conf/02_vswitch.conf 
}

copy_vswitch_dpdk()
{
\cp $CASE_PATH/beaker_ci_conf/02_vswitch_dpdk.conf /root/vswitchperf/conf/02_vswitch.conf
}

del_custom_conf_traffic(){
sed -i '/TRAFFICGEN_XENA_IP =/d'  /root/vswitchperf/conf/10_custom.conf
sed -i '/TRAFFICGEN_XENA_PORT1 =/d'  /root/vswitchperf/conf/10_custom.conf
sed -i '/TRAFFICGEN_XENA_PORT2 =/d'  /root/vswitchperf/conf/10_custom.conf
sed -i '/TRAFFICGEN_XENA_MODULE1 =/d'  /root/vswitchperf/conf/10_custom.conf
sed -i '/TRAFFICGEN_XENA_MODULE2 =/d'  /root/vswitchperf/conf/10_custom.conf
sed -i '/TRAFFICGEN_XENA_USER =/d'  /root/vswitchperf/conf/10_custom.conf
sed -i '/TRAFFICGEN_XENA_PASSWORD =/d'  /root/vswitchperf/conf/10_custom.conf
sed -i '/TRAFFICGEN_TREX_HOST_IP_ADDR =/d' /root/vswitchperf/conf/10_custom.conf
sed -i '/TRAFFICGEN_TREX_USER =/d' /root/vswitchperf/conf/10_custom.conf
sed -i '/TRAFFICGEN_TREX_BASE_DIR =/d' /root/vswitchperf/conf/10_custom.conf
sed -i '/TRAFFICGEN_TREX_PORT1 =/d' /root/vswitchperf/conf/10_custom.conf
sed -i '/TRAFFICGEN_TREX_PORT2 =/d' /root/vswitchperf/conf/10_custom.conf
sed -i '/TRAFFICGEN_TREX_FORCE_PORT_SPEED =/d' /root/vswitchperf/conf/10_custom.conf
sed -i '/TRAFFICGEN_TREX_PORT_SPEED =/d' /root/vswitchperf/conf/10_custom.conf
}

sos_report(){
yum install -y sos
rm -rf /var/tmp/sosreport*
sosreport --batch
}

install_qemu() {

if [ "$QCOW_LOC" == "China" ]
    then
    SERVER="download.eng.pnq.redhat.com"
elif [ "$QCOW_LOC" == "Westford" ]
    then
    SERVER="download-node-02.eng.bos.redhat.com"
fi

. /etc/os-release
OS_NAME="$VERSION_ID"
if (($(bc <<< "$VERSION_ID < 8"))); then
QEMU_VER=$1
if [ "$QEMU_VER" == "OSP8" ]
        then
        yum install -y qemu-kvm-rhev* >> ${CASE_PATH}/qemu_install.log

elif [ "$QEMU_VER" == "29" ]
    then
    	mkdir ~/qemu29
	wget http://$SERVER/brewroot/packages/qemu-kvm-rhev/2.9.0/16.el7_4.13/x86_64/qemu-img-rhev-2.9.0-16.el7_4.13.x86_64.rpm -P ~/qemu29
	wget http://$SERVER/brewroot/packages/qemu-kvm-rhev/2.9.0/16.el7_4.13/x86_64/qemu-kvm-common-rhev-2.9.0-16.el7_4.13.x86_64.rpm -P ~/qemu29
	wget http://$SERVER/brewroot/packages/qemu-kvm-rhev/2.9.0/16.el7_4.13/x86_64/qemu-kvm-rhev-2.9.0-16.el7_4.13.x86_64.rpm -P ~/qemu29
	wget http://$SERVER/brewroot/packages/qemu-kvm-rhev/2.9.0/16.el7_4.13/x86_64/qemu-kvm-tools-rhev-2.9.0-16.el7_4.13.x86_64.rpm -P ~/qemu29
    	rpm -e qemu-kvm-rhev-2.6.0-28.el7_3.9.x86_64 --nodeps >> ${CASE_PATH}/qemu_install.log
    	rpm -e qemu-kvm-common-rhev-2.6.0-28.el7_3.9.x86_64 --nodeps >> ${CASE_PATH}/qemu_install.log
    	rpm -e qemu-img-rhev-2.6.0-28.el7_3.9.x86_64 --nodeps >> ${CASE_PATH}/qemu_install.log
    	rpm -e qemu-kvm-tools-rhev-2.6.0-28.el7_3.9.x86_64 --nodeps >> ${CASE_PATH}/qemu_install.log
    	yum install -y http://download-node-02.eng.bos.redhat.com/brewroot/packages/seabios/1.10.2/3.el7_4.1/noarch/seabios-bin-1.10.2-3.el7_4.1.noarch.rpm
    	yum install -y http://download-node-02.eng.bos.redhat.com/brewroot/packages/seabios/1.10.2/3.el7_4.1/noarch/seavgabios-bin-1.10.2-3.el7_4.1.noarch.rpm
    	yum install -y http://download-node-02.eng.bos.redhat.com/brewroot/packages/ipxe/20170123/1.git4e85b27.el7_4.1/noarch/ipxe-roms-qemu-20170123-1.git4e85b27.el7_4.1.noarch.rpm
    	yum install -y ~/qemu29/qemu-img-rhev-2.9.0-16.el7_4.13.x86_64.rpm >> ${CASE_PATH}/qemu_install.log
    	yum install -y ~/qemu29/qemu-kvm-rhev-2.9.0-16.el7_4.13.x86_64.rpm >> ${CASE_PATH}/qemu_install.log
    	yum install -y ~/qemu29/qemu-kvm-common-rhev-2.9.0-16.el7_4.13.x86_64.rpm >> ${CASE_PATH}/qemu_install.log
    	yum install -y ~/qemu29/qemu-kvm-tools-rhev-2.9.0-16.el7_4.13.x86_64.rpm >> ${CASE_PATH}/qemu_install.log
    	yum install -y ~/qemu29/qemu-kvm-rhev-2.9.0-16.el7_4.13.x86_64.rpm >> ${CASE_PATH}/qemu_install.log
elif [ "$QEMU_VER" == "210" ]
    then
    	mkdir ~/qemu210
	wget http://$SERVER/brewroot/packages/qemu-kvm-rhev/2.10.0/20.el7/x86_64/qemu-img-rhev-2.10.0-20.el7.x86_64.rpm -P ~/qemu210/.
	wget http://$SERVER/brewroot/packages/qemu-kvm-rhev/2.10.0/20.el7/x86_64/qemu-kvm-common-rhev-2.10.0-20.el7.x86_64.rpm -P ~/qemu210/.
	wget http://$SERVER/brewroot/packages/qemu-kvm-rhev/2.10.0/20.el7/x86_64/qemu-kvm-rhev-2.10.0-20.el7.x86_64.rpm -P ~/qemu210/.
	wget http://$SERVER/brewroot/packages/qemu-kvm-rhev/2.10.0/20.el7/x86_64/qemu-kvm-rhev-debuginfo-2.10.0-20.el7.x86_64.rpm -P ~/qemu210/.
	wget http://$SERVER/brewroot/packages/qemu-kvm-rhev/2.10.0/20.el7/x86_64/qemu-kvm-tools-rhev-2.10.0-20.el7.x86_64.rpm -P ~/qemu210/.
	rpm -e qemu-kvm-rhev-2.6.0-28.el7_3.9.x86_64 --nodeps >> ${CASE_PATH}/qemu_install.log
        rpm -e qemu-kvm-common-rhev-2.6.0-28.el7_3.9.x86_64 --nodeps >> ${CASE_PATH}/qemu_install.log
        rpm -e qemu-img-rhev-2.6.0-28.el7_3.9.x86_64 --nodeps >> ${CASE_PATH}/qemu_install.log
        rpm -e qemu-kvm-tools-rhev-2.6.0-28.el7_3.9.x86_64 --nodeps >> ${CASE_PATH}/qemu_install.log
	pushd ~/qemu210
	yum install * -y
	popd
elif [ "$QEMU_VER" == "212" ]
    then
	qemu_install
fi
elif [ "$QEMU_VER" == "custom" ]
    then
cat > /etc/yum.repos.d/qemu.repo << _EOF
[qemu]
name=qemu
baseurl=${custom_qemu_url}
enabled=1
gpgcheck=0
skip_if_unavailable=1
_EOF
	yum -y remove @virt
	yum module reset virt -y
	yum module enable virt:8.3/common -y
	yum install --repo qemu qemu-kvm -y
else
	dnf module install virt -y
fi

}

qemu_install() {
        yum install -y $QEMU_IMG_RHEV
        yum install -y $QEMU_KVM_RHEV
        yum install -y $QEMU_KVM_COMMON_RHEV
        yum install -y $QEMU_KVM_TOOLS_RHEV
        yum install -y $QEMU_KVM_RHEV
        yum install -y qemu-kvm
}

init_conf() {
    conf_path="${CASE_PATH}/${CUSTOM_CONF}"

    ls "${conf_path}"/*.conf | while read line; do
        if ! cat $line |grep -q "VSWITCH_DPDK_MULTI_QUEUES"; then
            continue
        fi
        if ! cat $line |grep -q "BEAKER_PMD_NUM"; then
            continue
        fi
        # hex mask of host pmd
        host=$(cat $line |grep "BEAKER_PMD_NUM"|awk -F'=' '{print $2}')
        mask=$(/usr/bin/python2 ${CASE_PATH}/get_pmd.py --cmd host_pmd --nic "${NIC1}" --pmd "${host}")
        echo "VSWITCH_PMD_CPU_MASK = '$mask'" >> $line
        # guest pmd 
        queue=$(cat $line |grep "VSWITCH_DPDK_MULTI_QUEUES"|awk -F'=' '{print $2}')
        cpu=$(($queue * 2 + 1))
        guest=$(/usr/bin/python2 ${CASE_PATH}/get_pmd.py --cmd guest_pmd --nic "${NIC1}" --cpu $cpu)
        echo "GUEST_CORE_BINDING = $guest" >> $line
        #dpdk args
        args=$(/usr/bin/python2 ${CASE_PATH}/get_pmd.py --cmd dpdk_args --nic "${NIC1}")
        echo "VSWITCHD_DPDK_ARGS = $args" >> $line
        #dpdk config
        dpdk_config=$(/usr/bin/python2 ${CASE_PATH}/get_pmd.py --cmd dpdk_config --nic "${NIC1}")
        echo "VSWITCHD_DPDK_CONFIG = $dpdk_config" >> $line
        #nic_pci args
        echo 'WHITELIST_NICS = ["'${NIC1_PCI_ADDR}'", "'${NIC2_PCI_ADDR}'"]' >> $line
        . /etc/os-release
        if [ "$NIC_DRIVER" == "nfp" ];then
	    sed -i "s/L3/L2/g" $line
        fi
   done
   spec_dpdk_args=$(/usr/bin/python2 ${CASE_PATH}/get_pmd.py --cmd spec_dpdk_args --nic "${NIC1}")
   echo "VSWITCHD_DPDK_ARGS = ${spec_dpdk_args}" >> ${CASE_PATH}/${CUSTOM_CONF}/10_custom_baseline_testpmd_as_switch.conf
   echo 'WHITELIST_NICS = ["'${NIC1_PCI_ADDR}'|vf1", "'${NIC2_PCI_ADDR}'|vf1"]' >> ${CASE_PATH}/${CUSTOM_CONF}/10_custom_baseline_guest_novlan.conf
   echo "BEAKER_NIC_DRIVER='${NIC_DRIVER}'" >> /root/vswitchperf/conf/11_beaker.conf
   echo "NIC1_MAC='${NIC1_MAC}'" >> /root/vswitchperf/conf/12_mac.conf
   echo "NIC2_MAC='${NIC2_MAC}'" >> /root/vswitchperf/conf/12_mac.conf
   echo "NIC1='${NIC1}'" >> /root/vswitchperf/conf/13_nic.conf
   echo "NIC2='${NIC2}'" >> /root/vswitchperf/conf/13_nic.conf
   last_2cpu=$(/usr/bin/python2 ${CASE_PATH}/get_pmd.py --cmd last_cpu --nic "${NIC1}" --cpu 2)
   echo "VSWITCH_VHOST_CPU_MAP = ${last_2cpu}" >> ${CASE_PATH}/${CUSTOM_CONF}/10_custom_ovsvanilla_1q_linuxbridge.conf
   last_4cpu=$(/usr/bin/python2 ${CASE_PATH}/get_pmd.py --cmd last_cpu --nic "${NIC1}" --cpu 4)
   echo "VSWITCH_VHOST_CPU_MAP = ${last_4cpu}" >> ${CASE_PATH}/${CUSTOM_CONF}/10_custom_ovsvanilla_2q_linuxbridge.conf

dpdk_version=`rpm -qa dpdk|awk -F '-' '{printf $2}' |awk -F '.' '{printf $1}'`
if [ $dpdk_version -ge 17 ];then
ls "${conf_path}"/*.conf | while read line; do
cat <<EOT >> $line
PATHS['dpdk'] = {
        'type' : 'bin',
        'src': {
            'path': '/usr/share/dpdk',
            # To use vfio set:
            'modules' : ['uio', 'vfio-pci'],
            #'modules' : ['uio', os.path.join(RTE_TARGET, 'kmod/igb_uio.ko')],
            'bind-tool': 'usertools/dpdk*bind.py',
            'testpmd': os.path.join(RTE_TARGET, 'app', 'testpmd'),
        },
        'bin': {
            'bind-tool': 'driverctl',
            'modules' : ['vfio-pci'],
            'testpmd' : 'testpmd'
        }
    }
EOT
done
fi

if [ $dpdk_version -ge 20 ];then
ls "${conf_path}"/*.conf | while read line; do
cat <<EOT >> $line
PATHS['dpdk'] = {
        'type' : 'bin',
        'src': {
            'path': '/usr/share/dpdk',
            # To use vfio set:
            'modules' : ['uio', 'vfio-pci'],
            #'modules' : ['uio', os.path.join(RTE_TARGET, 'kmod/igb_uio.ko')],
            'bind-tool': 'usertools/dpdk*bind.py',
            'testpmd': os.path.join(RTE_TARGET, 'app', 'testpmd'),
        },
        'bin': {
            'bind-tool': 'driverctl',
            'modules' : ['vfio-pci'],
            'testpmd' : 'dpdk-testpmd'
        }
    }
EOT
done
fi

ls "${conf_path}"/*.conf | while read line; do
    sed -i "s/rhel7.4/rhel${GUEST_IMG}/g" $line
done

if [ $rxq_assign == "true" ];then
ls "${conf_path}"/*.conf | while read line; do
    sed -i 's/VSWITCHD_DPDK_CONFIG = {/VSWITCHD_DPDK_CONFIG = {"pmd-rxq-assign":"roundrobin",/g' $line
done
fi

if [ "$QEMU_VER" != "OSP8" ];then
ls "${conf_path}"/*.conf | while read line; do
echo "VSWITCH_VHOSTUSER_SERVER_MODE = False" >> $line
echo "VSWITCH_VHOSTUSER_SERVER_MODE = True" >> ${CASE_PATH}/${CUSTOM_CONF}/10_custom_baseline_testpmd_as_switch.conf
done
fi

echo "VANILLA_TGEN_PORT1_MAC = '${VANILLA_TGEN_PORT1_MAC}'" >> ${CASE_PATH}/${CUSTOM_CONF}/10_custom_ovsvanilla_1q_linuxbridge.conf
echo "VANILLA_TGEN_PORT2_MAC = '${VANILLA_TGEN_PORT2_MAC}'" >> ${CASE_PATH}/${CUSTOM_CONF}/10_custom_ovsvanilla_1q_linuxbridge.conf
echo "VANILLA_TGEN_PORT1_MAC = '${VANILLA_TGEN_PORT1_MAC}'" >> ${CASE_PATH}/${CUSTOM_CONF}/10_custom_ovsvanilla_2q_linuxbridge.conf
echo "VANILLA_TGEN_PORT2_MAC = '${VANILLA_TGEN_PORT2_MAC}'" >> ${CASE_PATH}/${CUSTOM_CONF}/10_custom_ovsvanilla_2q_linuxbridge.conf
}

init_custom_conf()
{
ls "${conf_path}"/*.conf | while read line; do
	sed -i '/VSWITCH_PMD_CPU_MASK =/d' $line
	sed -i '/GUEST_CORE_BINDING =/d' $line
	sed -i '/VSWITCHD_DPDK_ARGS =/d' $line
	sed -i '/VSWITCHD_DPDK_CONFIG =/d' $line

        echo "VSWITCHD_DPDK_CONFIG = ${VSWITCHD_DPDK_CONFIG}" >> $line
	echo "DPDK_SOCKET_MEM = ${DPDK_SOCKET_MEM}" >> $line
        echo $line
	if [[ $line == *2pmd* ]];then
        	echo "VSWITCH_PMD_CPU_MASK = ${VSWITCH_2PMD_CPU_MASK}" >> $line
	elif [[ $line == *4pmd* ]];then
        	echo "VSWITCH_PMD_CPU_MASK = ${VSWITCH_4PMD_CPU_MASK}" >> $line
	elif [[ $line == *8pmd* ]];then
        	 echo "VSWITCH_PMD_CPU_MASK = ${VSWITCH_8PMD_CPU_MASK}" >> $line
	fi
	if [[ $line == *1q* ]];then
        	echo "GUEST_CORE_BINDING = ${GUEST_CORE_BINDING_1Q}" >> $line
	elif [[ $line == *2q* ]];then
        	echo "GUEST_CORE_BINDING = ${GUEST_CORE_BINDING_2Q}" >> $line
	elif [[ $line == *4q* ]];then
        	echo "GUEST_CORE_BINDING = ${GUEST_CORE_BINDING_4Q}" >> $line
	fi

	if [[ $line == *dpdk* ]] || [[ $line == *ovsvanilla* ]] ;then
        	echo "VSWITCHD_DPDK_ARGS = ${VSWITCHD_DPDK_ARGS}" >> $line
	elif [[ $line == *baseline* ]];then
		echo "VSWITCHD_DPDK_ARGS = ${VSWITCHD_DPDK_ARGS}" >> $line
		echo "GUEST_CORE_BINDING = ${GUEST_CORE_BINDING_1Q}" >> $line
		echo "VSWITCH_PMD_CPU_MASK = ${VSWITCH_2PMD_CPU_MASK}" >> $line
	elif [[ $line == *switch* ]];then
        	echo "VSWITCHD_DPDK_ARGS = ${VSWITCHD_DPDK_ARGS_SWITCH_AS_SWITCH}" >> $line
	fi
done


}
add_verification()
{
   conf_path="${CASE_PATH}/${CUSTOM_CONF}"

   ls "${conf_path}"/*.conf | while read line; do  
        echo "TRAFFICGEN_XENA_RFC2544_VERIFY = True" >> $line
        echo "TRAFFICGEN_TREX_VERIFICATION_MODE = True" >> $line
   done
}

copy_ovsvanilla_openvswitch(){
    mkdir -p /usr/lib/modules/3.10.0-514.el7.x86_64/kernel/net/openvswitch/
    wget http://netqe-infra01.knqe.lab.eng.bos.redhat.com/vm/openvswitch.ko -P /usr/lib/modules/3.10.0-514.el7.x86_64/kernel/net/openvswitch/.
}

install_selinux_rpm()
{
        #when enable setforce1, need it
        yum install -y policycoreutils-python
        rpm -ivh http://download-node-02.eng.bos.redhat.com/brewroot/packages/container-selinux/2.36/1.gitff95335.el7/noarch/container-selinux-2.36-1.gitff95335.el7.noarch.rpm
        rpm -ivh http://download-node-02.eng.bos.redhat.com/brewroot/packages/openstack-selinux/0.8.12/0.20171204232656.7e9ef4a.el7ost/noarch/openstack-selinux-0.8.12-0.20171204232656.7e9ef4a.el7ost.noarch.rpm
}

install_python3_pkt()
{

cat <<'EOT' >> /etc/yum.repos.d/python36.repo
[centos-sclo-rh]
name=CentOS-7 - SCLo rh
baseurl=http://mirror.centos.org/centos/7/sclo/$basearch/rh/
gpgcheck=0
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-SCLo
EOT

wget --no-check-certificate  https://pypi.python.org/packages/source/s/setuptools/setuptools-19.6.tar.gz#md5=c607dd118eae682c44ed146367a17e26
tar -zxvf setuptools-19.6.tar.gz
cd setuptools-19.6
python3 setup.py build
python3 setup.py install
# comment out log to install python36-devel or python34-devel based on RHEL version and instead just install python36-devel
#if (($(bc <<< "$VERSION_ID >= 8"))); then
#    yum install python36-devel gcc -y
#else
#    yum install python34-devel gcc -y
#fi
yum install python36-devel gcc -y
pip3 install -r ${CASE_PATH}/requirements.txt

if (($(bc <<< "$VERSION_ID >= 8"))); then
    yum install python3-tkinter python2 -y
else
    yum -y install rh-python36 rh-python36-python-tkinter
    yum -y install scl-utils
fi
}

install_pip() {
    #wget "https://pypi.python.org/packages/source/p/pip/pip-1.5.4.tar.gz#md5=834b2904f92d46aaa333267fb1c922bb" --no-check-certificate
    pushd /root/
    wget https://files.pythonhosted.org/packages/69/81/52b68d0a4de760a2f1979b0931ba7889202f302072cc7a0d614211bc7579/pip-18.0.tar.gz
    tar -xzvf pip-18.0.tar.gz >> ${CASE_PATH}/pip_install.log
    pushd pip-18.0
    python2 ./setup.py install >> ${CASE_PATH}/pip_install.log
    popd
    echo "pip2 -V" 
    pip2 -V
    echo "pip3 -V"
    pip3 -V
}

run_one_time(){
        local func=`echo $1|awk -F ' ' '{printf $1}'`
        if [ ! -f "${CASE_PATH}/$func" ]; then
                $1
                touch "${CASE_PATH}/$func"
        fi
}

install_googlesheet(){
	sh ${CASE_PATH}/report/install_google.sh
}

create_config(){
	echo "NIC_DRIVER=""'$NIC_DRIVER'" >> ${CASE_PATH}/report/config.py
	echo "TRAFFIC_GEN=""'$TRAFFIC_GEN'" >> ${CASE_PATH}/report/config.py
	echo "NIC1=""'$NIC1'" >> ${CASE_PATH}/report/config.py
	echo "NIC2=""'$NIC2'" >> ${CASE_PATH}/report/config.py
}
