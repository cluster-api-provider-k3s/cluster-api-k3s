# importing a vm template into proxmox

A standard KVM optimized Ubuntu 22.04 image can be imported via

```
TEMPLATE_URL=https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-disk-kvm.img
TEMPLATE_VMID=10000
TEMPLATE_NAME=ubuntu-22.04
TEMPLATE_STORAGE=tank
TEMPLATE_DISK_OPTIONS="discard=on,iothread=1,ssd=1"

curl -o template.img ${TEMPLATE_URL}

qm create "${TEMPLATE_VMID}" --name ${TEMPLATE_NAME} --memory 16
qm importdisk "${TEMPLATE_VMID}" template.img "${TEMPLATE_STORAGE}"
qm set "${TEMPLATE_VMID}" \
    --scsihw virtio-scsi-single \
    --scsi0 ${TEMPLATE_STORAGE}:vm-${TEMPLATE_VMID}-disk-0,${TEMPLATE_DISK_OPTIONS} \
    --boot order=scsi0 \
    --cpu host \
    --rng0 source=/dev/urandom \
    --template 1 \
    --agent 1 \
    --onboot 1
```
Then for Ubuntu to work properly, you have to extend the `preK3sCommands` of both `KThreesConfigTemplate` and `KThreesControlPlane` with `apt update && apt -y install qemu-guest-agent && systemctl enable --now qemu-guest-agent`
