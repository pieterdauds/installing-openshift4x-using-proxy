# installing OpenShift4.3.33 Using Proxy
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
> **Note :** (1) For VMWare VMs set Latency Sensitivity to High (Edit Settings => VM Options => Latency Sensitivity (2) Master Must 3VMs


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

You can Download using this command
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
> **Note:** Replace the `pullSecret` and `sshKey` with your own.

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
3. In a few second display showing PXE Boot installer
![bootstrap](https://raw.githubusercontent.com/pieterdauds/openshift4x-proxy/master/bootstrap.png)
4. Run 1 Bootstrap and 3 Masters simultaneously.
