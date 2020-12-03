#!/bin/bash -x

echo "Building PhotonOS DNS Appliance with PhotonOS 4 Beta ..."
rm -f output-vmware-iso/*.ova

echo "Applying packer build to photon.json ..."
packer build -var-file=photon-builder.json -var-file=photon-versionP4.json photonP4.json

