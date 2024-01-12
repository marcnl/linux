#!/bin/sh

#### CONFIG DETAILS TO FILL IN ####

# minio/s3-compatible settings
aws_access_key_id='1q2w3e4r5t6y7u8i9o0p'
aws_secret_access_key='1q2w3e4r5t6y7u8i9o0p'
s3endpoint='https://192.168.1.125:9000'
minioskipSSLVerify='true'
region='nl-home-lab-1'
bucketname='k10-2'

# vsphere settings
vsphere_user='Administrator@vsphere.local'
vsphere_password='Veeam123!'
vsphereserverAddress='192.168.1.124'

# vbr settings
vbr_user='marc@backup.lab'
vbr_password='Veeam123!'
vbrserverAddress='192.168.1.127'
vbrskipSSLVerify='true'
repoName='Scale-out Backup Repository - DC1'

########



### DON'T CHANGE ANYTHING BELOW HERE ###

# Delete existing secrets and profiles created by this script on earlier executions
kubectl delete secret k10-vsphere-infra-secret -n kasten-io 2> /dev/null
kubectl delete secret k10-vbr-secret -n kasten-io 2> /dev/null
kubectl delete secret k10-s3-secret -n kasten-io 2> /dev/null
rm minio-vnas-profile.yaml vsphere-profile.yaml vbr-profile.yaml 2> /dev/null



## MINIO VNAS PROFILE ##
kubectl create secret generic k10-s3-secret \
      --namespace kasten-io \
      --type secrets.kanister.io/aws \
      --from-literal=aws_access_key_id='$aws_access_key_id' \
      --from-literal=aws_secret_access_key='$aws_secret_access_key'

cat <<EOF >>minio-vnas-profile.yaml
apiVersion: config.kio.kasten.io/v1alpha1
kind: Profile
metadata:
  name: minio-vnas
  namespace: kasten-io
spec:
  type: Location
  locationSpec:
    credential:
      secretType: AwsAccessKey
      secret:
        apiVersion: v1
        kind: Secret
        name: k10-minios3-secret
        namespace: kasten-io
    type: ObjectStore
    objectStore:
      name: minio-k8s-s3-bucket
      objectStoreType: S3
      endpoint: $s3endpoint
      skipSSLVerify: $minioskipSSLVerify
      name: $bucketname
      region: $region
EOF
kubectl apply -f minio-vnas-profile.yaml



### VSPHERE PROFILE ###
kubectl create secret generic k10-vsphere-infra-secret \
      --namespace kasten-io \
      --from-literal=vsphere_user=$vsphere_user \
      --from-literal=vsphere_password=$vsphere_password

cat <<EOF >>vsphere-profile.yaml
apiVersion: config.kio.kasten.io/v1alpha1
kind: Profile
metadata:
  name: vsphere
  namespace: kasten-io
spec:
  type: Infra
  infra:
    type: VSphere
    vsphere:
      serverAddress: $vsphereserverAddress
      taggingEnabled: true
    credential:
      secretType: VSphereKey
      secret:
        apiVersion: v1
        kind: Secret
        name: k10-vsphere-infra-secret
        namespace: kasten-io
EOF

kubectl apply -f vsphere-profile.yaml



### VBR PROFILE ###
kubectl create secret generic k10-vbr-secret \
  --namespace kasten-io \
  --from-literal=vbr_user=$vbr_user \
  --from-literal=vbr_password=$vbr_password

cat <<EOF >>vbr-profile.yaml
apiVersion: config.kio.kasten.io/v1alpha1
kind: Profile
metadata:
  name: vbr
  namespace: kasten-io
spec:
  type: Location
  locationSpec:
    credential:
      secretType: VBRKey
      secret:
        apiVersion: v1
        kind: Secret
        name: k10-vbr-secret
        namespace: kasten-io
    type: VBR
    vbr:
      repoName: $repoName
      serverAddress: $vbrserverAddress
      serverPort: 9419
      skipSSLVerify: $vbrskipSSLVerify
EOF

kubectl apply -f vbr-profile.yaml


mv minio-vnas-profile.yaml vsphere-profile.yaml vbr-profile.yaml ./yaml
