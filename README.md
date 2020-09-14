# Installing OpenShift 4.3.33 (Baremetal Install) Using Proxy in VMWare Env
## Preparing Installation
*Hardware/VM Minimum Req Spec
- Bootstrap	:  vCPU => 4
			         RAM	=> 16 GB
			         HDD	=> 130 GB
               IP   => 192.168.1.22
			   
- Master 	:  vCPU => 4
			       RAM	=> 16 GB
			       HDD	=> 130 GB
             IP   => 192.168.1.11 - 13
			   
- Worker	:  vCPU => 4
			       RAM	=> 16 GB
			       HDD	=> 150 GB
             IP   => 192.168.1.17 - 19
			   
- Helper	:  vCPU => 4
			       RAM	=> 4 GB
			       HDD	=> 150 GB
             IP   => 192.168.1.10
> **Note :** (1) Set Latency Sensitivity to High (Edit Settings => VM Options => Latency Sensitivity (2) Master Must 3VMs


Create installation directory
```
mkdir -p /root/installer/ocpdev
```
Clone configuration from GIT
```
cd /root/installer/ocpdev/
git clone https://github.com/pieterdauds/openshift4x-proxy.git
```

## Install Needed Tools
```
yum install -y bind bind-utils named net-tools vim wget httpd tftp-server haproxy syslinux-tftpboot python36 epel-release-latest-7.noarch && yum install -y jq oniguruma
```

## Download & Preparation CoreOS Installation
Move to Installation directory
```
cd /root/installer/
```
Go to https://cloud.redhat.com
 - Select REDHAT OPENSHIFT CLUSTER MANAGER
 - click new cluster
 - click Run On Bare Metal
 - Copy Pull Secret
 - Download Installer => openshift-install-linux.tar.gz
 - Download Command Line Tools => openshift-client-linux.tar.gz
 - Download rhcos-metal.raw.gz
 - Download rhcos-installer-initramfs.img
 - Download rhcos-installer-kernel
 
OR

You can Download using this command.

OpenShift Binaries
```
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.3.33/openshift-client-linux-4.3.33.tar.gz
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.3.33/openshift-install-linux-4.3.33.tar.gz
```
OpenShift CoreOS
```
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.3/4.3.33/rhcos-4.3.33-x86_64-metal.x86_64.raw.gz
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.3/4.3.33/rhcos-4.3.33-x86_64-installer-initramfs.x86_64.img
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.3/4.3.33/rhcos-4.3.33-x86_64-installer-kernel-x86_64
```

## DNS Settings (named)
Move to  configuration directory
```
cd /root/installer/ocpdev/
```
Copy dns configuration files
```
cp named/named.conf /etc/named.conf
cp named/ocpdev.example.com /var/named/ocpdev.example.com
cp named/1.168.192.in-addr.arpa /var/named/1.168.192.in-addr.arpa
```
Set Helper DNS to installed named server
```
nmtui
```
OR
```
echo "nameserver 192.168.1.10" >> /etc/resolv.conf
```
> **Note:** Make sure DNS Settings is valid and reply detail FQDN/IP. dns check command : dig @localhost -t srv _etcd-server-ssl._tcp.ocpdev.example.com. | dig @localhost bootstrap.ocpdev.example.com | dig -x 192.168.1.22

Start DNS Server
```
systemctl start named
```

## Load Balancer Settings (haproxy)
Copy LB Settings files
```
cp haproxy/haproxy.conf /etc/haproxy/haproxy.conf
```
> **Note:** Port 6443 : bootstrap and master ( API ) | Port 22623 : bootstrap and master ( machine config ) | Port 80 : router ( ingress http ) | Port 443 : router ( ingress https ) | Port 9000 : GUI for HAProxy 

Start DNS Service
```
systemctl start named
systemctl status named
```

## DNSMasq Settings
Copy DNSMasq Server settings
```
cp dnsmasq/dnsmasq.conf /etc/dnsmasq.conf
```
Copy DNSMasq PXE settings
```
cp dnsmasq/dnsmasq-pxe.conf /etc/dnsmasq.d/dnsmasq-pxe.conf
```
> **Note:** MAC Address is obtained from VMs/Servers

Start DNSMasq Service
```
systemctl start dnsmasq
systemctl status dnsmasq
```

## HTTPD Settings
Copy httpd server settings
```
cp httpd/httpd.conf /etc/httpd/conf/httpd.conf
```
Create httpd RHCOS directory and copy the RHCOS bios file
```
mkdir -p /var/www/html/metal/
cp /root/installer/rhcos-metal-bios.raw.gz /var/www/html/metal/
```

## TFTP Settings
Create RHCOS directory and copy pxelinux configuration
```
mkdir -p /var/lib/tftpboot/pxelinux.cfg/
mkdir -p /var/lib/tftpboot/rhcos/
cp /root/installer/rhcos-installer-initramfs.img /var/lib/tftpboot/rhcos/rhcos-initramfs.img
cp /root/installer/rhcos-installer-kernel /var/lib/tftpboot/rhcos/rhcos-kernel
```
Copy TFTP Server Configuration
```
cp pxelinux.cfg/default /var/lib/tftpboot/pxelinux.cfg/default
```
> **Note:** coreos.inst.install_dev : storage location.  | coreos.inst.ignition_url : ignition file url.

Start TFTP Service
```
systemctl start tftp
systemctl status tftp
```

## Creating Ignition Files
Extract Binary files and move to `/usr/bin ` directory
```
tar -xzvf /root/installer/openshift-client-linux.tar.gz
tar -xzvf /root/installer/openshift-install-linux.tar.gz
mv /root/installer/oc /root/installer/kubectl /root/installer/openshft-install /usr/bin/
```
Edit the `install-config.yaml` file
```
vi install-config.yaml
```
```
apiVersion: v1
baseDomain: example.com
proxy:
  httpsProxy: http://192.168.1.5:8080
  httpProxy: http://192.168.1.5:8080
  noProxy: .example.com,.ocpdev.example.com,192.168.1.0/24,api-int.ocpdev.example.com,api.ocpdev.example.com,registry.ocpdev.example.com
compute:
- hyperthreading: Enabled
  name: worker
  replicas: 0
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 1
metadata:
  name: ocpdev
networking:
  clusterNetworks:
  - cidr: 10.254.0.0/16
    hostPrefix: 24
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  none: {}
pullSecret: '{"auths": ...}' <<- INSERT YOUR Pull Secret from cloud.redhat.com
sshKey: 'ssh-ed25519 AAAA...' <<-- insert ssh Pub
```
> **Note:** Replace the `pullSecret`, `sshKey` and `proxy` with your own. | in this case noProxy is mandatory and must be filled! 

Create OpenShift Manifests 
```
openshift-install create manifests
```
Patch manifests `master scheduler` to false
```
sed -i 's/mastersSchedulable: true/mastersSchedulable: false/g' manifests/cluster-scheduler-02-config.yml
```
Generate ignition configs
```
openshift-install create ignition-configs
```
Copy ignition files to httpd web servers
```
cp *.ign /var/www/html/
```
> **Note:** Run `openshift-install` command in directory containing the install-config.yaml file.

## Install The Cluster
1. Run `Bootstrap` & `Master` VMs
2. Boot via LAN for executing PXE Boot installation
3. In a few second display will showing PXE Boot installer UI
4. Run 1 Bootstrap and 3 Masters simultaneously.
.
![bootstrap](https://raw.githubusercontent.com/pieterdauds/openshift4x-proxy/master/images/bootstrap.png)
.
![master](https://raw.githubusercontent.com/pieterdauds/openshift4x-proxy/master/images/master.png)
.
5. For monitoring Bootstrap status you can use this command (run from Helper VM in /root/installer/devocp/ dir)
```
openshift-install wait-for bootstrap-complete --log-level debug
```
> **Note:** For verbose monitoring Bootstrap logs you can remote the Bootstrap node using this command `ssh core@bootstrap.ocpdev.example.com` and run `journalctl` command.

wait until show logs like this :
```
DEBUG OpenShift Installer v4.2.1
DEBUG Built from commit e349157f325dba2d06666987603da39965be5319
INFO Waiting up to 30m0s for the Kubernetes API at https://api.ocpdev.example.com:6443...
INFO API v1.14.6+868bc38 up
INFO Waiting up to 30m0s for bootstrapping to complete...
DEBUG Bootstrap status: complete
INFO It is now safe to remove the bootstrap resources
```
6. Remove `Bootstrap` record from LB Settings
```
cp haproxy/haproxy.cfg.patch /etc/haproxy/haproxy.cfg
```
7. After showing log "INFO It is now safe to remove the bootstrap resources" poweroff the bootstrap VM and check your own cluster
```
export KUBECONFIG=/root/installer/ocpdev/auth/kubeconfig
oc get nodes
```
```
NAME                       STATUS   ROLES     AGE    VERSION
master-0.ocpdev.example.com   Ready    master    3d6h   v1.16.2+554af56
master-1.ocpdev.example.com   Ready    master    3d6h   v1.16.2+554af56
master-2.ocpdev.example.com   Ready    master    3d6h   v1.16.2+554af56
```
8. Check Operator Cluster Status
```
oc get co
```
```
NAME                                       VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE
authentication                             4.3.33     True        False         True       
cloud-credential                           4.3.33     True        False         False     
cluster-autoscaler                         4.3.33     True        False         False     
console                                    4.3.33     True        False         True       
dns                                        4.3.33     False       True          True      
image-registry                             4.3.33     False       True          False     
ingress                                    4.3.33     False       True          False     
insights                                   4.3.33     True        False         True      
kube-apiserver                             4.3.33     True        True          True       
kube-controller-manager                    4.3.33     True        False         True       
kube-scheduler                             4.3.33     True        False         True       
machine-api                                4.3.33     True        False         False     
machine-config                             4.3.33     False       False         True       
marketplace                                4.3.33     True        False         False     
monitoring                                 4.3.33     False       True          True       
network                                    4.3.33     True        True          False     
node-tuning                                4.3.33     False       False         True       
openshift-apiserver                        4.3.33     False       False         False     
openshift-controller-manager               4.3.33     False       False         False     
openshift-samples                          4.3.33     True        False         False     
operator-lifecycle-manager                 4.3.33     True        False         False     
operator-lifecycle-manager-catalog         4.3.33     True        False         False     
operator-lifecycle-manager-packageserver   4.3.33     False       True          False     
service-ca                                 4.3.33     True        True          False     
service-catalog-apiserver                  4.3.33     True        False         False     
service-catalog-controller-manager         4.3.33     True        False         False     
storage                                    4.3.33     True        False         False
```
in this case the Openshift Cluster Operator is in install process, you can check installation status using this command
```
openshift-install wait-for install-complete
```
9. Add worker server to cluster
Run worker VMs and boot via PXE Boot again, and select `worker` in UI menu.
![worker](https://raw.githubusercontent.com/pieterdauds/openshift4x-proxy/master/images/worker.png)
10. By default OpenShift cluster cant approve worker CSR automaticly, you must approve certificate manually using this command
Show all CSR certificate
```
oc get csr
```
Approve selected CSR certificate
```
oc adm certificate approve `CSRNAME`
```
OR you can approve all CSR certificate uisng this command
```
oc get csr --no-headers | awk '{print $1}' | xargs oc adm certificate approve
```
11. Check cluster nodes
Make sure the `worker` nodes successfully join to the OpenShift4.3.33 cluster.
```
oc get nodes
```
```
NAME                       STATUS   ROLES     AGE    VERSION
master-0.ocpdev.example.com   Ready    master    3d6h   v1.16.2+554af56
master-1.ocpdev.example.com   Ready    master    3d6h   v1.16.2+554af56
master-2.ocpdev.example.com   Ready    master    3d6h   v1.16.2+554af56
worker-0.ocpdev.example.com   Ready    master    3d6h   v1.16.2+554af56
worker-1.ocpdev.example.com   Ready    master    3d6h   v1.16.2+554af56
worker-2.ocpdev.example.com   Ready    master    3d6h   v1.16.2+554af56
```
