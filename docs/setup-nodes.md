# Setting up a node VM on TrueNAS

Do these before running `install/k3s.sh`. For the VM screens, see
[TrueNAS VMs](https://www.truenas.com/docs/scale/scaletutorials/virtualization/).

> **The VM's System Clock must be set to UTC in TrueNAS.** On the default,
> *Local*, every boot starts hours off. k3s then creates certificates that
> aren't valid yet, and the node goes `NotReady` after each VM restart.

## Checklist

- [ ] **System Clock: UTC.** Power the VM off, change it, then start it. A
      reboot from inside the guest doesn't apply it.
- [ ] **Disk:** a VirtIO zvol of at least 100GB. Images, game installs,
      worlds, backups, Prometheus and Loki all live on it. A zvol can grow,
      but not shrink.
- [ ] **NIC:** VirtIO, attached to a **bridge**. With macvtap, the VM can't
      reach the TrueNAS host.
- [ ] **Stable IP:** port forwards, Grafana and `.env` files all pin it.
      Use a fixed MAC plus a router DHCP reservation, and/or a static IP
      outside the DHCP pool.
- [ ] **CPU:** 1 socket × N cores × 1 thread; inflated topologies waste idle CPU.
- [ ] **RAM:** fixed, with no Minimum Memory (ballooning), and no swap in the
      guest ([swap](https://kubernetes.io/docs/concepts/cluster-administration/swap-memory-management/)).
- [ ] **Housekeeping:** autostart on, a periodic zvol snapshot task, and a
      hostname you won't change.

## In the guest

```sh
# The Ubuntu installer's LVM uses ~half the disk. Grow it (again after any zvol resize):
sudo growpart /dev/sda 3 && sudo pvresize /dev/sda3
sudo lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv

# Static IP: edit /etc/netplan/*.yaml. Run from the VM console, not SSH:
sudo netplan try

# Rootless podman image builds need a subuid/subgid range for the build user,
# or any non-root file in an image fails with "value too large for defined
# data type". Pick a 65536 range no other user in /etc/subuid holds:
sudo usermod --add-subuids 231072-296607 --add-subgids 231072-296607 "$(id -un)"
podman system migrate
```

For the netplan file, see the
[netplan examples](https://netplan.readthedocs.io/en/stable/examples/)
(`dhcp4: false`, `addresses`, `routes`, `nameservers`). If the IP changes,
also update the router's port forwards, `VM_HOST` and `monitoring/site.env`.

## Node NotReady after a restart?

That's almost always the clock:

```sh
timedatectl   # want: synchronized yes, "RTC in local TZ: no"
echo | openssl s_client -connect 127.0.0.1:10250 2>/dev/null \
  | openssl x509 -noout -startdate; date -u   # start date in the future = bad clock
sudo systemctl restart k3s   # once the clock is right: regenerates the certs
```
