## Configure your Proxmox parameters

if [ -z "${CLUSTER_NAME}" ]; then
  echo "Please set CLUSTER_NAME"
  exit 0
fi

if [ -z "${KUBERNETES_VERSION}" ]; then
  echo "Please set KUBERNETES_VERSION. For ex. v1.31.2+k3s1"
  exit 0
fi

if [ -z "${CONTROL_PLANE_ENDPOINT_IP}" ]; then
  echo "Please set CONTROL_PLANE_ENDPOINT_IP. For ex. '10.10.10.4'"
  exit 0
fi

if [ -z "${NODE_IP_RANGES}" ] || [ -z "${GATEWAY}" ] || [ -z "${IP_PREFIX}" ] || [ -z "${DNS_SERVERS}" ] || [ -z "${BRIDGE}" ]; then
  echo "Please set NODE_IP_RANGES. For ex. '[10.10.10.5-10.10.10.50]'"
  echo "Please set GATEWAY. For ex. '10.10.10.1'"
  echo "Please set IP_PREFIX. For ex. '24'"
  echo "Please set DNS_SERVERS. For ex. '[8.8.8.8,8.8.4.4]'"
  echo "Please set BRIDGE. For ex. 'vmbr0'"
  exit 0
fi

if [ -z "${PROXMOX_URL}" ] || [ -z "${PROXMOX_TOKEN}" ] || [ -z "${PROXMOX_SECRET}" ] || [ -z "${PROXMOX_SOURCENODE}" ] || [ -z "${PROXMOX_TEMPLATE_VMID}" ]; then
  echo "Please set PROXMOX_URL, PROXMOX_TOKEN, PROXMOX_SECRET, PROXMOX_SOURCENODE, PROXMOX_TEMPLATE_VMID"
  echo "- See https://github.com/ionos-cloud/cluster-api-provider-proxmox/blob/main/docs/Usage.md"
  exit 0
fi

# The device used for the boot disk.   
export BOOT_VOLUME_DEVICE="scsi0"                                    
# The size of the boot disk in GB.
export BOOT_VOLUME_SIZE="32"                                        
# The number of sockets for the VMs.
export NUM_SOCKETS="1"                                               
# The number of cores for the VMs.
export NUM_CORES="1"                                                 
# The memory size for the VMs.
export MEMORY_MIB="4069"                                             

# K3s components to disable
# For example because you plan to use MetalLB over ServiceLB, or Longhorn over local-storage, or...
# export K3S_DISABLE_COMPONENTS="[servicelb,local-storage,traefik,metrics-server,helm-controller]"

## Install your cluser-api-k3s provider correctly
mkdir -p ~/.cluster-api
cat samples/clusterctl.yaml | envsubst > ~/.cluster-api/clusterctl.yaml

cat >> ~/.cluster-api/clusterctl.yaml <<EOC
- name: "in-cluster"
  url: https://github.com/kubernetes-sigs/cluster-api-ipam-provider-in-cluster/releases/latest/ipam-components.yaml
  type: "IPAMProvider"
EOC

clusterctl init \
    --infrastructure proxmox \
    --bootstrap k3s \
    --control-plane k3s \
    --ipam in-cluster

kubectl wait --for=condition=Available --timeout=5m \
    -n capi-system deployment/capi-controller-manager
kubectl wait --for=condition=Available --timeout=5m \
    -n capi-k3s-control-plane-system deployment/capi-k3s-control-plane-controller-manager
kubectl wait --for=condition=Available --timeout=5m \
    -n capi-k3s-bootstrap-system deployment/capi-k3s-bootstrap-controller-manager
kubectl wait --for=condition=Available --timeout=5m \
    -n capmox-system deployment/capmox-controller-manager

clusterctl generate cluster \
    "${CLUSTER_NAME}" \
    --from samples/proxmox/cluster-template-k3s.yaml \
    | kubectl apply -f -

echo "Once the cluster is up, run 'clusterctl get kubeconfig $CLUSTER_NAME > k3s.yaml' to retrieve your kubeconfig"
echo "- Run 'kubectl scale kthreescontrolplane $CLUSTER_NAME-control-plane --replicas 3' to enable HA for your control-planes"
echo "- or run 'kubectl scale machinedeployment $CLUSTER_NAME-worker --replicas 3' to deploy worker nodes"
echo "- or to just use the single node cluster, you might need to also run the following commands:"
echo "    kubectl taint nodes --all node-role.kubernetes.io/control-plane-"
echo "    kubectl taint nodes --all node-role.kubernetes.io/master-"
