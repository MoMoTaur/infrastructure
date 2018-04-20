# MAGFest IT Infrastructure

## Creating a salt-master control server

Creating a salt-master control server should only need to be done rarely—ideally just once. The salt-master control server is the central piece of MAGFest's IT infrastructure used to provision and manage all of our other servers.

1. Create a new droplet on https://digitalocean.com
  * Ubuntu 16.04.4 x64
  * **Optional**: Add a block storage volume (this will need to be mounted on `/srv/data`)
  * Select "Private Networking" and "Monitoring"
  * Add the following SSH Keys: "Saltmaster", "Rob Ruana", and "DomMCP"
2. By default the salt-minions will attempt to connect to `saltmaster.magfest.net`, so the DNS entry for `saltmaster.magfest.net` on https://dnsmadeeasy.com should be updated to point to the new droplet's **Private IP**
3. SSH to the new server
4. If applicable, follow Digital Ocean's instructions for configuring and mounting your block storage volume on `/srv/data`.
  * If you're adding a _new_ volume, you'll need to format the volume. As root/sudo run:
```
mkfs.ext4 -F /dev/disk/by-id/scsi-0DO_Volume_volume-nyc1-01
```
  * If you're mounting an already formatted volume:
```
mkdir -p /srv/data; \
mount -o discard,defaults /dev/disk/by-id/scsi-0DO_Volume_volume-nyc1-01 /srv/data; \
echo /dev/disk/by-id/scsi-0DO_Volume_volume-nyc1-01 /srv/data ext4 defaults,nofail,discard 0 0 | tee -a /etc/fstab
```
5. As root/sudo run:
```
curl -L https://github.com/magfest/infrastructure/raw/master/bootstrap-mcp.sh | sh
```
