#!/bin/bash
#by raysuen
#v1.0
#


#################################################################################
#Before exec this script:
#    You must put the the software --LINUX.X64_193000_db_home.zip to base dir. 
#			example: My base dir is /u01.
#	 You must mount the OS ISO ,then you must sure can exec yum
#	 Attention: all password is "oracle" that is used by the new users appearing
#           after the script.
#################################################################################



export LANG=C

#################################################################################
#before the bash you must install necessary rpm for oracle and edit hostname    #
#################################################################################

c_yellow="\e[1;33m"
c_red="\e[1;31m"
c_end="\e[0m"

echo ""
echo -e "${c_red}please confirm that you have put the script and software into the base dir.${c_end}"
echo ""

####################################################################################
#stop firefall  and disable selinux
####################################################################################
StopFirewallAndDisableSelinux(){
	systemctl stop firewalld
	systemctl disable firewalld
	if [ "`/usr/sbin/getenforce`" != "Disabled" ];then
		/usr/sbin/setenforce 0
	fi
	if [ ! -z `grep "SELINUX=enforcing" /etc/selinux/config` ];then
		cp /etc/selinux/config /etc/selinux/config.$(date +%F)
		sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
	fi
	
}

####################################################################################
#obtain ip
####################################################################################
ObtainIP(){
	if [ "${eth:-None}" == "None" ];then
		echo "internet name:"
		for i in `ip addr | egrep "^[0-9]" | awk -F ':' '{print $2}'`
		do
			echo -e "	\e[1;33m"$i": "`ifconfig $i | egrep -v "inet6" | awk -F 'net|netmaskt' '{print $2}' | sed ':label;N;s/\n//;b label' | sed -e 's/ //g' -e 's/)//g'`"\e[0m"
		done
		
		while true
		do
			read -p "`echo -e "please enter the name of Ethernet，default [${c_yellow}lo${c_end}]: "`" eth
			ipaddr=`ifconfig ${eth:-lo} 2> /dev/null | egrep -v "inet6" | awk -F'inet|netmask' '{print $2}' | sed ':label;N;s/\n//;b label' | sed 's/ //g'`
			[ "${ipaddr:-None}" == "None" ]&& echo -e "pleas input the ${c_red}exact name of Ethernet${c_end}"&& continue
			if [ -n "$(echo ${ipaddr} | sed 's/[0-9]//g' | sed 's/.//g')" ];then
				echo -e 'shell can not obtain ip,pleas input the ${c_red}exact name of Ethernet${c_end}'
			continue
			else
				break
			fi
		done
	else
		ipaddr=`ifconfig ${eth:-lo} 2> /dev/null | egrep -v "inet6" | awk -F'inet|netmask' '{print $2}' | sed ':label;N;s/\n//;b label' | sed 's/ //g'`
		if [ "${ipaddr:-None}" == "None" ];then
    		echo -e "please enter ${c_red}a exiting interface name${c_end} "
    		exit 96
  		fi
	fi
}

####################################################################################
#obtain base dir
####################################################################################
ObtainBasedir(){
	if [ "${basedir:-None}" == "None" ];then
		while true
		do
			read -p "`echo -e "please enter the name of base dir,put this shell and software in the dir.default [${c_yellow}/u01${c_end}]: "`" bdir
			basedir=${bdir:-/u01}  #this is base dir,put this shell and software in the dir
			if [ ! -d ${basedir} ];then
		    	echo -e "the ${basedir} is not exsist,please ${c_red}make it up${c_end}"
		    	continue
			else
		    	break
		  	fi
		done
	else
		if [ ! -d ${basedir} ];then
			echo -e "the ${basedir} is not exsist,please ${c_red}make it up${c_end}"
			exit 95
		fi
	fi 
}

####################################################################################
#obtain ORACLE_SID
####################################################################################
ObtainSID(){
	if [ "${osid:-None}" == "None" ];then
		read -p "`echo -e "please enter the sid.default [${c_yellow}orcl${c_end}]: "`" osid
	fi
	
	####################################################################################
	#get container
	####################################################################################
	while true
	do
		read -p "`echo -e "Do you create container database？ yes/no. Default \e[1;33m no \e[0m: "`" ContainerConfirm
		if [ ${ContainerConfirm:-no} == "no" ];then
			break
		elif [ ${ContainerConfirm:-no} == "yes" ];then
			read -p "`echo -e "PDB name:  "`" PDBName
			if [ ! ${PDBName} ];then
				echo "PDB name must be not empty!"
				continue
			else
				break
			fi
		else
			echo "You only enter yes or no."
			continue
		fi
	done
	
	#echo ${osid}
	orasid=${osid:-orcl}
	su - oracle -c "sed -i 's/^ORACLE_SID=$/ORACLE_SID='${orasid}'/g' ~/.bash_profile"
	#source ~/.bash_profile
	
}

####################################################################################
#obtain the characterSet for instance
####################################################################################
ObtainCharacter(){
	if [ "${Inchar:-None}" == "None" ];then
		echo "please enter the characterSet for your instance."
		echo "(1) ZHS16GBK"
		echo "(2) AL32UTF8"
		while true
		do
			read -p "`echo -e ".Please enter 1 or 2 to choose character: "`" Inchar
			if [ ! ${Inchar} ];then
				echo "You must enter 1 or 2 to choose the character."
				continue
			elif [ ${Inchar} -eq 1 ];then
				InCharacter=ZHS16GBK  #this is character of instance. 
				break
			elif [ ${Inchar} -eq 2 ];then
				InCharacter=AL32UTF8  #this is character of instance. 
				break
			else
				echo "You must enter 1 or 2 to choose the character."
				continue
			fi
			
			
		done
	fi 
}


####################################################################################
#obtain the momery percentage of the oracle using server momery
####################################################################################
ObtainMemPerc(){
	if [ "${mper:-None}" == "None" ];then
		while true
		do
			read -p "`echo -e "Please enter the momery percentage of the oracle using server momery.default [${c_yellow}60${c_end}]: "`" mper
			perusemom=${mper:-60}
			if [ -n "`echo ${perusemom} | sed 's/[0-9]//g' | sed 's/-//g'`" ];then
				echo -e "please enter ${c_red}exact number${c_end}"
				continue
		  	else
				[ "${perusemom}" -ge "90" ]&& echo -e "the percentage can not be greater than ${c_red}90${c_end}"&& continue
		    	break
		  	fi
		done
	else
		perusemom=${mper}
	fi
	#sed -i 's/^MEMORYPERCENTAGE = \"\"$/MEMORYPERCENTAGE = "'${perusemom}'"/g' ${basedir}/dbca.rsp
	
}

####################################################################################
#install rpm that oracle is necessary for installing
####################################################################################
InstallRPM(){
	mountPatch=`mount | egrep "iso|ISO|^/dev/sr" | awk '{print $3}'`
	if [ ! ${mountPatch} ];then
		echo "No ios file is mounted. Please check whether the YUM/DNF command can install the RPM package."
        	while true
            do
				read -p "`echo -e "Go on to install? [${c_yellow}yes/no${c_end}]: "`" isgo
				if [ ! ${isgo} ];then
					echo -e "${c_yellow}You must enter yes or no.${c_end}"
					continue
				elif [ ${isgo} == "yes" ];then
					break
				elif [ ${isgo} == "no" ];then
					exit 0
				fi
            done
    else
    	if [ -d /etc/yum.repos.d/`date +"%Y%m%d"` ];then
			[ `ls /etc/yum.repos.d/*.repo | grep -v "local*" | wc -l` -gt 0 ] && mv -f /etc/yum.repos.d/*.repo /etc/yum.repos.d/`date +"%Y%m%d"`/
		else
			if [ `ls /etc/yum.repos.d/*.repo | grep -v "local*" | wc -l` -gt 0 ];then
		 		mkdir -p /etc/yum.repos.d/`date +"%Y%m%d"` && mv -f /etc/yum.repos.d/*.repo /etc/yum.repos.d/`date +"%Y%m%d"`/
			fi
		fi 
    	[ -f "/etc/yum.repos.d/local.repo" ] && sed -i '/^#OraConfBegin/,/^#OraConfEnd/d' /etc/yum.repos.d/local.repo
    	echo "
#OraConfBegin
[InstallMedia-BaseOS]
name=Red Hat Enterprise Linux 8 - BaseOS
metadata_expire=-1
gpgcheck=1
enabled=1
baseurl=file://${mountPatch}/BaseOS/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

[InstallMedia-AppStream]
name=Red Hat Enterprise Linux 8 - AppStream
metadata_expire=-1
gpgcheck=1
enabled=1
baseurl=file://${mountPatch}/AppStream/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
#OraConfBegin
" >> /etc/yum.repos.d/local.repo

	fi
	dnf -y install bc --nogpgcheck
	dnf -y install binutils --nogpgcheck
	dnf -y install elfutils-libelf --nogpgcheck
	dnf -y install elfutils-libelf-devel --nogpgcheck
	dnf -y install fontconfig-devel --nogpgcheck
	dnf -y install glibc --nogpgcheck
	dnf -y install glibc-devel --nogpgcheck
	dnf -y install ksh --nogpgcheck
	dnf -y install libaio --nogpgcheck
	dnf -y install libaio-devel --nogpgcheck
	dnf -y install libXrender --nogpgcheck
	dnf -y install libX11 --nogpgcheck
	dnf -y install libXau --nogpgcheck
	dnf -y install libXi --nogpgcheck
	dnf -y install libXtst --nogpgcheck
	dnf -y install libgcc --nogpgcheck
	dnf -y install libnsl --nogpgcheck
	dnf -y install librdmacm --nogpgcheck
	dnf -y install libstdc++ --nogpgcheck
	dnf -y install libstdc++-devel --nogpgcheck
	dnf -y install libxcb --nogpgcheck
	dnf -y install libibverbs --nogpgcheck
	dnf -y install make --nogpgcheck
	dnf -y install policycoreutils --nogpgcheck
	dnf -y install policycoreutils-python-utils --nogpgcheck
	dnf -y install smartmontools --nogpgcheck
	dnf -y install sysstat --nogpgcheck
	dnf -y install ipmiutil --nogpgcheck
	dnf -y install libnsl2 --nogpgcheck
	dnf -y install libnsl2-devel  --nogpgcheck
	dnf -y install net-tools --nogpgcheck
	dnf -y install nfs-utils --nogpgcheck
	dnf -y install unixODBC --nogpgcheck

	#dnf localinstall ./libnsl2-devel-1.2.0-2.20180605git4a062cf.el8.x86_64.rpm  --nogpgcheck
	# -y localinstall compat-libstdc++-33-3.2.3-72.el7.x86_64.rpm 
	#yum -y localinstall elfutils-libelf-devel-0.168-8.el7.x86_64.rpm
	[ `ls ${basedir}/libnsl2-devel* 2>/dev/null | wc -l` -eq 1 ] && ls ${basedir}/libnsl2-devel* | awk -v rpmpackage="" '{rpmpackage=$NF" "rpmpackage}END{print "dnf -y localinstall "rpmpackage" --nogpgcheck"}' | bash 
	while true
	do
		if [ `rpm -q unzip bc binutils elfutils-libelf elfutils-libelf-devel fontconfig-devel glibc glibc-devel ksh libaio libaio-devel libXrender libX11 libXau libXi libXtst libgcc libnsl librdmacm libstdc++ libstdc++-devel libxcb libibverbs make policycoreutils policycoreutils-python-utils smartmontools sysstat ipmiutil libnsl2 libnsl2-devel  net-tools nfs-utils unixODBC  --qf '%{name}.%{arch}\n' | grep "not installed" | wc -l` -gt 0 ];then
			echo -e "${c_yellow}RPM not intalled list${c_end}:"
			rpm -q unzip bc binutils elfutils-libelf elfutils-libelf-devel fontconfig-devel glibc glibc-devel ksh libaio libaio-devel libXrender libX11 libXau libXi libXtst libgcc libnsl librdmacm libstdc++ libstdc++-devel libxcb libibverbs make policycoreutils policycoreutils-python-utils smartmontools sysstat ipmiutil libnsl2 libnsl2-devel  net-tools nfs-utils unixODBC  --qf '%{name}.%{arch}\n' | grep "not installed"
			echo " "
			read -p "`echo -e "Please confirm that all rpm package have installed.[${c_yellow}yes/no${c_end}] default yes:"`" ans
			if [ "${ans:-yes}" == "yes" ];then
				break
			else
				continue
			fi
		else
			break
		fi
	done
}

####################################################################################
#obtain basic infomation
####################################################################################
ObtainBasicInfo(){
	################################################################################
	#obtain hostname
	################################################################################
	sname=$(hostname) 
	[ -z ${sname} ]&& echo -e 'shell can not obtain ${c_red}hostname${c_end},shell interrupt forcedly'&&exit 1

	################################################################################
	#obtain ORACLE_BASE ORACLE_HOME
	################################################################################
	orabase="${basedir}/app/oracle"    #set path of oracle_base
	orahome="${basedir}/app/oracle/product/19.3.0/dbhome_1" #set path of oracle_home
	
}


####################################################################################
#check swap,swap must be greater then 150M
####################################################################################
CheckSwap(){
	while true
	do
		swap=`free -m | grep Swap | awk '{print $4}'`
		if [[ ${swap} -lt 150 ]];then
			echo 'failed,swap less then 150M'
			echo 'please increase the space of swap, greater then 150M'
		else
			break
		fi
		echo "Have you been increased the space of swap?"
		read -p "`echo -e "Whether or not to check the space of swap? ${c_yellow}yes/no${c_end}. no will quit the intalling: "`" swapDone
		if [[ "${swapDone}" = "yes" ]];then
			continue
	  	elif [[ "${swapDone}" = "no" ]];then
	    	exit 94
	  	else
	  		echo "please enter yes/no"
	  		continue
	  	fi
	done
}

####################################################################################
# create user and groups for oracle installation,edit bash_profile
####################################################################################
CreateGUAndEditprofile(){
	####################################################################################
	# create user and groups for oracle installation
	####################################################################################
	if [ `egrep "oinstall" /etc/group | wc -l` -eq 0 ];then
		groupadd -g 11001 oinstall  
	fi
	if [ `egrep "dba" /etc/group | wc -l` -eq 0 ];then
		groupadd -g 11002 dba  
	fi
	if [ `egrep "oper" /etc/group | wc -l` -eq 0 ];then
		groupadd -g 11003 oper  
	fi
	if [ `egrep "backupdba" /etc/group | wc -l` -eq 0 ];then
		groupadd -g 11004 backupdba  
	fi
	if [ `egrep "dgdba" /etc/group | wc -l` -eq 0 ];then
		groupadd -g 11005 dgdba  
	fi
	if [ `egrep "kmdba" /etc/group | wc -l` -eq 0 ];then
		groupadd -g 11006 kmdba  
	fi
	if [ `egrep "racdba" /etc/group | wc -l` -eq 0 ];then
		groupadd -g 11007 racdba  
	fi
	
	#if [ `egrep "oinstall|dba|oper" /etc/group | wc -l` -eq 0 ];then
	#	groupadd -g 11001 oinstall  
	#	groupadd -g 11002 dba  
	#	groupadd -g 11003 oper  
	#	groupadd -g 11004 backupdba  
	#	groupadd -g 11005 dgdba  
	#	groupadd -g 11006 kmdba
	#	groupadd -g 11007 racdba
	#fi
	if [ `egrep "oracle" /etc/passwd | wc -l` -eq 0 ];then
		useradd -u 11011 -g oinstall -G dba,backupdba,dgdba,kmdba,oper,racdba oracle 
		if [ $? -ne 0 ];then
			echo "Oracle is not existing."
			exit  93
		fi
	fi
	
	
	echo "oracle" | passwd --stdin oracle
	if [ $? -ne 0 ];then
		echo "Oracle is not existing."
		exit  92
	fi
	####################################################################################
	#edit oracle's bash
	####################################################################################
	su - oracle -c "cp /home/oracle/.bash_profile /home/oracle/.bash_profile${daytime}.bak"
	su - oracle -c "sed -i '/^#OraConfBegin/,/^#OraConfEnd/d' /home/oracle/.bash_profile"
	su - oracle -c "echo \"#OraConfBegin\" >> /home/oracle/.bash_profile"
	su - oracle -c "echo 'ORACLE_BASE='${orabase} >> /home/oracle/.bash_profile"
	su - oracle -c "echo 'ORACLE_HOME='${orahome} >> /home/oracle/.bash_profile"
	su - oracle -c "echo 'ORACLE_SID=' >> /home/oracle/.bash_profile"
	su - oracle -c "echo 'export ORACLE_BASE ORACLE_HOME ORACLE_SID' >> /home/oracle/.bash_profile"
	su - oracle -c "echo 'export PATH=\$PATH:\$HOME/bin:\$ORACLE_HOME/bin' >> /home/oracle/.bash_profile"
	su - oracle -c "echo 'export NLS_LANG=AMERICAN_AMERICA.AL32UTF8' >> /home/oracle/.bash_profile"           #AL32UTF8,ZHS16GBK
	su - oracle -c "echo 'export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$ORACLE_HOME/lib' >> /home/oracle/.bash_profile"
	su - oracle -c "echo 'export CV_ASSUME_DISTID=OEL7' >> /home/oracle/.bash_profile"
	su - oracle -c "echo \"#OraConfEnd\" >> /home/oracle/.bash_profile"
	
	
	####################################################################################
	#create oracle home directory
	####################################################################################
	mkdir -p ${orahome}
	
}


####################################################################################
#edit linux parameter files
####################################################################################
EditParaFiles(){
	####################################################################################
	#obtain current day
	####################################################################################
	daytime=`date +%Y%m%d`
	####################################################################################
	#edit /etc/hosts
	####################################################################################
	sed -i '/^#OraConfBegin/,/^#OraConfEnd/d' /etc/hosts #delete content
	if [ `grep ${ipaddr} /etc/hosts | wc -l` -eq 0 ];then
		cp /etc/hosts /etc/hosts.${daytime}
		echo "#OraConfBegin" >> /etc/hosts
		echo ${ipaddr}'  '${sname} >> /etc/hosts
		echo "#OraConfEnd" >> /etc/hosts
	fi
	
	####################################################################################
	#edit sysctl.conf
	####################################################################################
	shmall=`/sbin/sysctl -a | grep "shmall" | awk '{print $NF}'`
	shmmax=`/sbin/sysctl -a | grep "shmmax" | awk '{print $NF}'`
	
	sed -i '/^#OraConfBegin/,/^#OraConfEnd/d' /etc/sysctl.conf #delete content
	cp /etc/sysctl.conf /etc/sysctl.conf.${daytime}
	echo "#OraConfBegin" >> /etc/sysctl.conf
	echo 'kernel.shmall = '${shmall} >> /etc/sysctl.conf
	echo 'kernel.shmmax = '${shmmax} >> /etc/sysctl.conf
	echo 'kernel.shmmni = 4096' >> /etc/sysctl.conf
	echo 'kernel.sem = 250 32000 100 128' >> /etc/sysctl.conf
	echo 'fs.file-max = 6815744' >> /etc/sysctl.conf
	echo 'net.ipv4.ip_local_port_range = 9000 65500' >> /etc/sysctl.conf
	echo 'net.core.rmem_default = 262144' >> /etc/sysctl.conf
	echo 'net.core.rmem_max = 4194304' >> /etc/sysctl.conf
	echo 'net.core.wmem_default = 262144' >> /etc/sysctl.conf
	echo 'net.core.wmem_max = 1048576' >> /etc/sysctl.conf
	echo 'fs.aio-max-nr=1048576' >> /etc/sysctl.conf
	echo "#OraConfEnd" >> /etc/sysctl.conf
	
	sysctl -p
	
	####################################################################################
	#edit limits.conf
	####################################################################################
	sed -i '/^#OraConfBegin/,/^#OraConfEnd/d' /etc/security/limits.conf
	cp /etc/security/limits.conf /etc/security/limits.conf.${daytime}
	echo "#OraConfBegin" >> /etc/security/limits.conf
	echo 'oracle soft nproc 2047' >> /etc/security/limits.conf
	echo 'oracle hard nproc 16384' >> /etc/security/limits.conf
	echo 'oracle soft nofile 1024' >> /etc/security/limits.conf
	echo 'oracle hard nofile 65536' >> /etc/security/limits.conf
	echo 'oracle soft stack 10240' >> /etc/security/limits.conf
	echo 'oracle hard stack 10240' >> /etc/security/limits.conf
	echo "#OraConfEnd" >> /etc/security/limits.conf
	
	####################################################################################
	#edit pam.d/login
	####################################################################################
	#sed -i '/^#OraConfBegin/,/^#OraConfEnd/d' /etc/pam.d/login
	#cp /etc/pam.d/login /etc/pam.d/login.${daytime}
	#echo "#OraConfBegin" >> /etc/pam.d/login
	#echo 'session required /lib64/security/pam_limits.so' >> /etc/pam.d/login
	#echo 'session required pam_limits.so' >> /etc/pam.d/login
	#echo "#OraConfEnd" >> /etc/pam.d/login
}

####################################################################################
#edit rdbms rsp files
####################################################################################
EditRdbmsRspFiles(){
	
	####################################################################################
	#edit responseFile of rdbms
	####################################################################################
		#SELECTED_LANGUAGES:en english,zh_CN:simplified Chinese
	if [ -f "${basedir}/rdbms.rsp" ];then
		rm -f ${basedir}/rdbms.rsp
	fi
	
	echo 'oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v18.0.0' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.option=INSTALL_DB_SWONLY' >> ${basedir}/rdbms.rsp
	echo 'UNIX_GROUP_NAME=oinstall' >> ${basedir}/rdbms.rsp
	echo 'INVENTORY_LOCATION='/${basedir}'/app/oraInventory' >> ${basedir}/rdbms.rsp
	echo 'ORACLE_BASE='${orabase} >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.InstallEdition=EE' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.OSDBA_GROUP=dba' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.OSOPER_GROUP=oper' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.OSBACKUPDBA_GROUP=backupdba' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.OSDGDBA_GROUP=dgdba' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.OSKMDBA_GROUP=kmdba' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.OSRACDBA_GROUP=racdba' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.CLUSTER_NODES=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.type=GENERAL_PURPOSE' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.globalDBName=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.SID=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.ConfigureAsContainerDB=false' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.PDBName=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.characterSet=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.memoryOption=false' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.memoryLimit=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.installExampleSchemas=false' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.password.ALL=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.password.SYS=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.password.SYSTEM=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.password.DBSNMP=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.password.PDBADMIN=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.managementOption=DEFAULT' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.omsHost=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.omsPort=0' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.emAdminUser=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.emAdminPassword=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.enableRecovery=false' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.storageType=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.fileSystemStorage.dataLocation=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.fileSystemStorage.recoveryLocation=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.asm.diskGroup=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.asm.ASMSNMPPassword=' >> ${basedir}/rdbms.rsp

	
	####################################################################################
	#change the owner and group of the  responseFile
	####################################################################################
	chown -R oracle:oinstall  ${basedir}
	chmod -R 755  ${basedir}

}


####################################################################################
#obtain install instance options
####################################################################################
ObtainInstanceOption(){
	echo -e ""
	while true
	do
		read -p "`echo -e "Do you want to install the database instance.${c_red}yes/no ${c_end} :"`" installoption
		if [ "${installoption:-None}" == "None" ];then
			echo "Please enter yes or no."
			continue
			
		elif [ "${installoption:-None}" == "no" ];then
			exit 0
		elif [ "${installoption:-None}" == "yes" ];then
			break
		else
			echo "Please enter valid value. yes/no."
			continue
		fi
	done
}


####################################################################################
#install RDBMS function
####################################################################################
InstallRdbms(){
	if [ ! -f "${basedir}/LINUX.X64_193000_db_home.zip" ];then
        echo "Database file not exists.Please ensure you have uploaded."
		exit 79
	else
		chown oracle:oinstall ${basedir}/LINUX.X64_193000_db_home.zip
		su - oracle -c "unzip -d ${orahome} ${basedir}/LINUX.X64_193000_db_home.zip"
		
	fi
	su - oracle -c "${orahome}/runInstaller -silent -noconfig -ignorePrereq -responseFile ${basedir}/rdbms.rsp > ${basedir}/install.log"
	#follow coding are create oracle instance.if you don't want to create install instance,you can use # making coding invalidly
	echo ' '
	echo ' '
	echo -e "you use the command to get information about installation:${c_red} tail -f ${basedir}/install.log${c_end}"
	sleep 1m
	echo ' '
	while true
	do
		installRes=`egrep "Successfully Setup Software" ${basedir}/install.log | awk '{print $1}'`
		if [[ "${installRes}" = "Successfully" ]];then
			${basedir}/app/oraInventory/orainstRoot.sh
			${orahome}/root.sh
			echo -e "${c_yellow} RDBMS has been installed.${c_end}"
			break
		else
			sleep 20s
			continue
		fi
	done
}


####################################################################################
#obtain the momery percentage of the oracle using server momery
####################################################################################
ObtainMemPerc(){
	if [ "${mper:-None}" == "None" ];then
		while true
		do
			read -p "`echo -e "Please enter the momery percentage of the oracle using server momery.default [${c_yellow}60${c_end}]: "`" mper
			perusemom=${mper:-60}
			if [ -n "`echo ${perusemom} | sed 's/[0-9]//g' | sed 's/-//g'`" ];then
				echo -e "please enter ${c_red}exact number${c_end}"
				continue
		  	else
				[ "${perusemom}" -ge "90" ]&& echo -e "the percentage can not be greater than ${c_red}90${c_end}"&& continue
		    	break
		  	fi
		done
	else
		perusemom=${mper}
	fi
	#sed -i 's/^MEMORYPERCENTAGE = \"\"$/MEMORYPERCENTAGE = "'${perusemom}'"/g' ${basedir}/dbca.rsp
	
}

####################################################################################
#obtain ORACLE_SID
####################################################################################
# ObtainSID(){
# 	if [ "${osid:-None}" == "None" ];then
# 		read -p "`echo -e "please enter the sid.default [${c_yellow}orcl${c_end}]: "`" osid
# 	fi
# 	#echo ${osid}
# 	orasid=${osid:-orcl}
# 	su - oracle -c "sed -i 's/^ORACLE_SID=$/ORACLE_SID='${orasid}'/g' ~/.bash_profile"
# 	
# 	
# }

####################################################################################
#edit dbca 19C rsp files
####################################################################################
EditDbca19CspFiles(){
	####################################################################################
	#edit responseFile of instance
	####################################################################################
	#ZHS16GBK
	if [ -f "${basedir}/dbca.rsp" ];then
		rm -f ${basedir}/dbca.rsp
	fi
	
	sga=`free -m | awk '/Mem/{print int($2*('${perusemom}'/100)*0.75)}'`
	pga=`free -m | awk '/Mem/{print int($2*('${perusemom}'/100)*0.25)}'`
	
	############################################################
	#Determine whether a container database needs to be created
	############################################################
	if [ ${#PDBName} -gt 0 ];then
		pdbnumber=1
		ispdb=true
		pdbAdminPWD=oracle
	else 
		pdbnumber=0
		ispdb=false
	fi
	
	
	echo 'responseFileVersion=/oracle/assistants/rspfmt_dbca_response_schema_v12.2.0' > ${basedir}/dbca.rsp
	echo 'gdbName='${orasid} >> ${basedir}/dbca.rsp
	echo 'sid='${orasid} >> ${basedir}/dbca.rsp
	echo 'databaseConfigType=SI' >> ${basedir}/dbca.rsp
	echo 'RACOneNodeServiceName=' >> ${basedir}/dbca.rsp
	echo 'policyManaged=false' >> ${basedir}/dbca.rsp
	echo 'createServerPool=false' >> ${basedir}/dbca.rsp
	echo 'serverPoolName=' >> ${basedir}/dbca.rsp
	echo 'cardinality= ' >> ${basedir}/dbca.rsp
	echo 'force=false  ' >> ${basedir}/dbca.rsp
	echo 'pqPoolName=  ' >> ${basedir}/dbca.rsp
	echo 'pqCardinality=' >> ${basedir}/dbca.rsp
	echo 'createAsContainerDatabase='${ispdb} >> ${basedir}/dbca.rsp
	echo 'numberOfPDBs='${pdbnumber} >> ${basedir}/dbca.rsp
	echo 'pdbName='${PDBName}    >> ${basedir}/dbca.rsp
	echo 'useLocalUndoForPDBs=true' >> ${basedir}/dbca.rsp
	echo 'pdbAdminPassword='${pdbAdminPWD} >> ${basedir}/dbca.rsp
	echo 'nodelist=    ' >> ${basedir}/dbca.rsp
	echo 'templateName='${orahome}'/assistants/dbca/templates/New_Database.dbt' >> ${basedir}/dbca.rsp
	echo 'sysPassword=oracle ' >> ${basedir}/dbca.rsp
	echo 'systemPassword=oracle ' >> ${basedir}/dbca.rsp
	echo 'serviceUserPassword=' >> ${basedir}/dbca.rsp
	echo 'emConfiguration=' >> ${basedir}/dbca.rsp
	echo 'emExpressPort=5500' >> ${basedir}/dbca.rsp
	echo 'runCVUChecks=FALSE' >> ${basedir}/dbca.rsp
	echo 'dbsnmpPassword=' >> ${basedir}/dbca.rsp
	echo 'omsHost=     ' >> ${basedir}/dbca.rsp
	echo 'omsPort=0    ' >> ${basedir}/dbca.rsp
	echo 'emUser=      ' >> ${basedir}/dbca.rsp
	echo 'emPassword=  ' >> ${basedir}/dbca.rsp
	echo 'dvConfiguration=false' >> ${basedir}/dbca.rsp
	echo 'dvUserName=  ' >> ${basedir}/dbca.rsp
	echo 'dvUserPassword=' >> ${basedir}/dbca.rsp
	echo 'dvAccountManagerName=' >> ${basedir}/dbca.rsp
	echo 'dvAccountManagerPassword=' >> ${basedir}/dbca.rsp
	echo 'olsConfiguration=false' >> ${basedir}/dbca.rsp
	echo 'datafileJarLocation=' >> ${basedir}/dbca.rsp
	echo 'datafileDestination=' >> ${basedir}/dbca.rsp
	echo 'recoveryAreaDestination=' >> ${basedir}/dbca.rsp
	echo 'storageType= ' >> ${basedir}/dbca.rsp
	echo 'diskGroupName=' >> ${basedir}/dbca.rsp
	echo 'asmsnmpPassword=' >> ${basedir}/dbca.rsp
	echo 'recoveryGroupName=' >> ${basedir}/dbca.rsp
	echo 'characterSet='${InCharacter} >> ${basedir}/dbca.rsp
	echo 'nationalCharacterSet=AL16UTF16' >> ${basedir}/dbca.rsp
	echo 'registerWithDirService=false' >> ${basedir}/dbca.rsp
	echo 'dirServiceUserName=' >> ${basedir}/dbca.rsp
	echo 'dirServicePassword=' >> ${basedir}/dbca.rsp
	echo 'walletPassword=' >> ${basedir}/dbca.rsp
	echo 'listeners=   ' >> ${basedir}/dbca.rsp
	echo 'variablesFile=' >> ${basedir}/dbca.rsp
	echo 'variables=ORACLE_BASE_HOME='${orahome}',DB_UNIQUE_NAME='${orasid}',ORACLE_BASE='${orabase}',PDB_NAME='${PDBName}',DB_NAME='${orasid}',ORACLE_HOME='${orahome}',SID='${orasid} >> ${basedir}/dbca.rsp
	echo 'initParams=undo_tablespace=UNDOTBS1,db_block_size=8192BYTES,nls_language=AMERICAN,dispatchers=(PROTOCOL=TCP) (SERVICE='${orasid}'XDB),diagnostic_dest={ORACLE_BASE},control_files=("{ORACLE_BASE}/oradata/{DB_UNIQUE_NAME}/control01.ctl", "{ORACLE_BASE}/oradata/{DB_UNIQUE_NAME}/control02.ctl"),remote_login_passwordfile=EXCLUSIVE,audit_file_dest={ORACLE_BASE}/admin/{DB_UNIQUE_NAME}/adump,processes=300,nls_territory=AMERICA,local_listener=LISTENER_TEST,pga_aggregate_target='${pga}'MB,sga_target='${sga}'MB,open_cursors=1000,compatible=18.0.0,db_name='${orasid}',audit_trail=db' >> ${basedir}/dbca.rsp
	echo 'sampleSchema=false' >> ${basedir}/dbca.rsp
	echo 'memoryPercentage='${perusemom} >> ${basedir}/dbca.rsp
	echo 'databaseType=MULTIPURPOSE' >> ${basedir}/dbca.rsp
	echo 'automaticMemoryManagement=false' >> ${basedir}/dbca.rsp
	echo 'totalMemory=0' >> ${basedir}/dbca.rsp
	
	
	chown oracle:oinstall ${basedir}/dbca.rsp
}

####################################################################################
#obtain datafile destination
####################################################################################
ObtainDatafileDir(){
	echo -e "Default datafile directory is ${c_yellow}${orabase}/oradata/${orasid}${c_end}"
	while true
	do
		read -p "`echo -e "You can specify another directory.Do you sure change datafile directory.default no .${c_yellow}yes/no ${c_end} :"`" ans
		if [ "${ans:-no}" == "yes" ];then
			while true
			do
				read -p "`echo -e "please enter your datafile directory: "`" datafiledir
				if [ "${datafiledir:-none}" == "none" ];then
					echo "The directory must be specified."
					continue
				else
					echo -e "The datafile directory is ${c_yellow}${datafiledir}${c_end}."
					read -p "`echo -e "Are you sure? Default yes. ${c_yellow}yes/no${c_end} :"`" ans2
					if [ "${ans2:-yes}" == "yes" ];then
						break
					else
						continue
					fi
				fi
			done
			break
			
		elif [ "${ans:-no}" == "no" ];then
			break
		else
			continue
		fi
	done
}


####################################################################################
#install instance
####################################################################################
InstallInstance(){
	while true
	do
		installRes=`egrep "Successfully Setup Software" ${basedir}/install.log | awk '{print $1}'`
		if [[ "${installRes}" = "Successfully" ]];then
			#create instance
			if [ "${datafiledir}" == "default" ];then
				su - oracle -c "dbca -silent -createDatabase -responseFile ${basedir}/dbca.rsp"
			elif [ -n "${datafiledir}" ];then
				if [ -d ${datafiledir} ];then
					chown oracle:oinstall ${datafiledir}
				else
					mkdir ${datafiledir}
					chown oracle:oinstall ${datafiledir}
				fi
				su - oracle -c "dbca -silent -createDatabase -responseFile ${basedir}/dbca.rsp -datafileDestination ${datafiledir}"
			else
				ObtainDatafileDir
				if [ "${datafiledir:-none}" == "none" ];then
					su - oracle -c "dbca -silent -createDatabase -responseFile ${basedir}/dbca.rsp "
				else
					if [ -d ${datafiledir} ];then
						chown oracle:oinstall ${datafiledir}
					else
						mkdir ${datafiledir}
						chown oracle:oinstall ${datafiledir}
					fi
					su - oracle -c "dbca -silent -createDatabase -responseFile ${basedir}/dbca.rsp  -datafileDestination ${datafiledir}"
				fi
			fi
			break
		else
			sleep 20s
			continue
		fi
	done

}


####################################################################################
#start listen,the port is 1521
####################################################################################
ConfigListen(){
	su - oracle -c "netca /silent /responsefile ${orahome}/assistants/netca/netca.rsp"
}

####################################################################################
#edit tnsnames.ora   
####################################################################################
ConfigTnsnames(){
	su - oracle -c "echo ${orasid}' =' >> ${orahome}/network/admin/tnsnames.ora"
	su - oracle -c "echo '  (DESCRIPTION =' >> ${orahome}/network/admin/tnsnames.ora"
	su - oracle -c "echo '    (ADDRESS_LIST =' >> ${orahome}/network/admin/tnsnames.ora"
	su - oracle -c "echo '      (ADDRESS = (PROTOCOL = TCP)(HOST = '${sname}')(PORT = 1521))' >> ${orahome}/network/admin/tnsnames.ora"
	su - oracle -c "echo '    )' >> ${orahome}/network/admin/tnsnames.ora"
	su - oracle -c "echo '    (CONNECT_DATA =' >> ${orahome}/network/admin/tnsnames.ora"
	su - oracle -c "echo '      (SERVICE_NAME = '${orasid}')' >> ${orahome}/network/admin/tnsnames.ora"
	su - oracle -c "echo '    )' >> ${orahome}/network/admin/tnsnames.ora"
	su - oracle -c "echo '  )' >> ${orahome}/network/admin/tnsnames.ora"
}

####################################################################################
#initial parameter
####################################################################################
InitialPara(){
	su - oracle -c "sqlplus /nolog <<-RAY
	conn / as sysdba
	ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED;
	alter system set open_cursors=1500 scope=both;
	alter system set session_cached_cursors=100 scope=spfile;
	alter system set processes=1000 scope=spfile;
	alter system set sessions=1000 scope=spfile;
	ALTER SYSTEM SET \"_use_adaptive_log_file_sync\"= false;
	exit
	RAY"
	
	su - oracle -c "sqlplus /nolog <<-RAY
	conn / as sysdba
	shutdown immediate;
	startup
	exit
	RAY"
}



####################################################################################
#install function
####################################################################################
InstallFun(){
	ObtainBasedir
	InstallRPM
	StopFirewallAndDisableSelinux
	ObtainIP
	ObtainBasicInfo
	CheckSwap
	CreateGUAndEditprofile
	EditParaFiles
	EditRdbmsRspFiles
	InstallRdbms
	if [ "${installoption}" == "no" ];then
		exit 0
	elif [ "${installoption:-None}" == "None" ];then
		ObtainInstanceOption
	fi
	#ObtainInstanceOption
	ObtainMemPerc
	ObtainSID
	ObtainCharacter
	EditDbca19CspFiles
	InstallInstance
	ConfigListen
	ConfigTnsnames
	InitialPara
}

####################################################################################
#begin to install
####################################################################################
InstallFun

####################################################################################
#The entry of the script
####################################################################################
#
#obtain the values of parameters
#
#while (($#>=1))
#do
#	#
#	#to sure is the parameter start with --
#	#
#	if [ `echo $1 | egrep "^--"` ];then
#		if [ "$1" == "--usedefaultdatapath" ];then
#			datafiledir="default"
#			shift
#			continue
#		fi 
#		if [ "$1" == "--notinstallinstance" ];then
#			installoption=no
#			shift
#			continue
#		fi
#		pastpara=$1
#		shift
#		if [ `echo $1 | egrep "^--"` ];then
#			echo "The value of ${pastpara} must be specified!"
#			exit 99
#		fi
#
#		case `echo $pastpara | sed s/--//g` in
#			listeninterface)
#				eth=$1
#			;;
#			basedirectory)
#				basedir=$1
#			;;
#			oraclesid)
#				osid=$1
#			;;
#			memorypercent)
#				mper=$1
#				if [ -n "`echo ${mper} | sed 's/[0-9]//g' | sed 's/-//g'`" ];then
#    				echo -e "please enter ${c_red}exact number${c_end} for $pastpara"
#    				exit 97
#  				fi
#			;;
#			oraclesoftname)
#				oraname=$1
#			;;
#			datafilepath)
#				datafiledir=$1
#			;;
#			help)
#				help_fun
#				exit 0
#			;;
#			*)
#				echo "$lastpara is a illegal parameter!"
#				exit 98
#			;;
#		esac
#	else
#		shift
#		continue
#	fi
#
#done

