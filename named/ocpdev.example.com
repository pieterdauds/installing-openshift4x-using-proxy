$TTL 604800
@   IN  SOA  helper.ocpdev.example.com.  root (
            2019052001  ; serial
            1D          ; refresh
            2H          ; retry
            1W          ; expiry
            2D )        ; minimum

@           IN NS       helper.ocpdev.example.com.
@           IN A        192.168.1.10

; Ancillary services
;lb          IN A        192.168.1.10
;lb-ext      IN A        192.168.1.10

; Bastion or Jumphost
lb                IN A        192.168.1.10
lb-ext            IN A        192.168.1.10
helper.ocpdev      IN A        192.168.1.10

; OCP Cluster
bootstrap.ocpdev   IN A        192.168.1.22
master-0.ocpdev    IN A        192.168.1.11
master-1.ocpdev    IN A        192.168.1.12
master-2.ocpdev    IN A        192.168.1.13
etcd-0.ocpdev      IN A        192.168.1.11
etcd-1.ocpdev      IN A        192.168.1.12
etcd-2.ocpdev      IN A        192.168.1.13
router-0.ocpdev    IN A        192.168.1.14
router-1.ocpdev    IN A        192.168.1.15
router-2.ocpdev    IN A        192.168.1.16
worker-0.ocpdev    IN A        192.168.1.17
worker-1.ocpdev    IN A        192.168.1.18
worker-2.ocpdev    IN A        192.168.1.19
logs-0.ocpdev      IN A        192.168.1.20
logs-1.ocpdev      IN A        192.168.1.21

_etcd-server-ssl._tcp.ocpdev 86400 IN SRV  0   10   2380    etcd-0.ocpdev.example.com.
_etcd-server-ssl._tcp.ocpdev 86400 IN SRV  0   10   2380    etcd-1.ocpdev.example.com.
_etcd-server-ssl._tcp.ocpdev 86400 IN SRV  0   10   2380    etcd-2.ocpdev.example.com.

api.ocpdev       IN CNAME   lb-ext
api-int.ocpdev   IN CNAME   lb

apps.ocpdev      IN CNAME   lb-ext
*.apps.ocpdev    IN CNAME   lb-ext
