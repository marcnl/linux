#!/usr/bin/bash
#
# make sure your vm has a second disk /dev/sdb that is completely empty (used for the zfs pool)
#
# source: https://gist.githubusercontent.com/tdewin/46d0c5e81481fe91f5c84184cb21e949/raw/dd3bf2446fd56ac1f80e5f7bc0fa439fc9e5ccf2/kasten-ubuntu-lab.sh
# source: https://github.com/tdewin


# NOTE1: A free range of (exactly!) 6 IP addresses is required for all the services!! Also, instead of installing MicroK8S 1.25, you can also select 1.24, 1.23, etc.
# NOTE2: Additional external IP's can be assigned to new services later on using the following command: # kubectl patch svc adguard-home --namespace=adguard-home -p '{"spec": {"type": "LoadBalancer", "externalIPs":["192.168.1.127"]}}'
#
# This script will:
# 1. Automatically deploy K8S incl. Kasten K10, MinIO, MySQL demo, Wordpress (with custom theme) and AdGuard Home
# 2. Automatically create an user, access and secret key and a bucket in MinIO and add it to K10
# 3. Automatically create (advanced) backup policies (and run them), presets and enable K10 Reporting
# 4. (optional) Deploy profiles for connecting with external MinIO storage, vCenter and VBR11 (watch the output at the end of the script)
#
# Run the command below on a fresh Ubuntu 22.04 install. The '| tee ./installer.log' is optional, only use it if you want to save screen output to a log file
#
# wget https://raw.githubusercontent.com/marcnl/linux/main/microk8s_126_install.sh && chmod +x ./microk8s_126_install.sh && ./microk8s_126_install.sh 1.26 192.168.1.151 192.168.1.156 2>&1 | tee ./installer.log



# These values are used for creating a ZFS pool, an user and a bucket in MinIO and a for the K10 infrastructure profile
ZFSDISK=/dev/sdb
user=k10user
access_key="1q2w3e4r5t6y7u8i9o0p"
secret_key="1q2w3e4r5t6y7u8i9o0p"
bucket=k10




### DON'T CHANGE ANYTHING BELOW HERE ###


#ADMINNAME=admin
KASTENTOKENAUTH=1

version=$1
FIRSTIP=$2
LASTIP=$3

if [ ! $1 ];then echo "One or more arguments is missing, run the command like this (make sure to adjust versions and IPs): $0 1.25 192.168.1.121 192.168.1.126";echo && exit -1 ;fi
if [ ! $2 ];then echo "One or more arguments is missing, run the command like this (make sure to adjust versions and IPs): $0 1.25 192.168.1.121 192.168.1.126";echo && exit -1 ;fi
if [ ! $3 ];then echo "One or more arguments is missing, run the command like this (make sure to adjust versions and IPs): $0 1.25 192.168.1.121 192.168.1.126";echo && exit -1 ;fi
if [ ! $(ls $ZFSDISK) ];then echo "ZFSDisk $ZFSDISK not found";exit -1 ;fi


#buggy minios3 auth
#read -p "First IP Range LB:" FIRSTIP && read -p "LAST IP Range LB:" LASTIP && read -s -p "Password for user $ADMINNAME: " BASICAUTH && echo "" && read -s -p "Password for user minio (simple) $ADMINNAME: " S3AUTH && echo ""
#read -p "First IP Range LB:" FIRSTIP && read -p "LAST IP Range LB:" LASTIP && read -s -p "Password for user $ADMINNAME: " BASICAUTH && echo ""
#read -s -p "Password for user $ADMINNAME: " BASICAUTH && echo ""

echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections
SECONDS=0
echo "\$nrconf{restart} = \"l\"" | sudo tee -a /etc/needrestart/needrestart.conf

sudo apt-get update -y && sudo apt-get install jq apache2-utils -y
sudo apt-get update -y && sudo apt-get upgrade -y

#echo $BASICAUTH | htpasswd  -ic auth $ADMINNAME


sudo echo "forcing sudo" && wget -c https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz -O - | tar -xz && \
  sudo mv ./linux-amd64/helm /bin && \
#  sudo wget -c "https://dl.k8s.io/release/$(wget -O - https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -O /bin/kubectl && \
#  sudo chmod 755 /bin/kubectl

#mkdir /etc/apt/keyrings
sudo apt-get install -y ca-certificates curl
sudo apt-get install -y apt-transport-https
#sudo curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
#echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
#sudo apt-get update
#sudo apt-get install -y kubectl
#sudo chmod 755 /bin/kubectl

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /bin/kubectl


#sudo echo "forcing sudo" && wget -c https://github.com/ahmetb/kubectx/releases/download/v0.9.3/kubens_v0.9.3_linux_x86_64.tar.gz -O - | tar -xz && \
#  sudo mv ./kubens /bin

#sudo echo "forcing sudo" && wget -c https://github.com/ahmetb/kubectx/releases/download/v0.9.3/kubectx_v0.9.3_linux_x86_64.tar.gz -O - | tar -xz && \
#  sudo mv ./kubectx /bin

wget -c https://github.com/ahmetb/kubectx/releases/download/v0.9.4/kubens_v0.9.4_linux_x86_64.tar.gz && tar -zxvf kubens* && \
  sudo mv ./kubens /bin
wget -c https://github.com/ahmetb/kubectx/releases/download/v0.9.4/kubectx_v0.9.4_linux_x86_64.tar.gz -O - | tar -xz && \
  sudo mv ./kubectx /bin

rm LICENSE kube*.tar.gz


sudo snap install microk8s --classic --channel=$version/stable
sudo microk8s.start
sudo microk8s.status

sudo microk8s enable dns #upstream will be 8.8.8.8 check doc for supplying custom (local) DNS
echo "Waiting for services to be initialized before installing Metallb" && sleep 60
sudo microk8s enable metallb:$FIRSTIP-$LASTIP 
sudo microk8s enable ingress

sudo usermod -a -G microk8s $(whoami)

sudo mkdir ~/.kube
sudo chown -f -R $(whoami) ~/.kube


sudo apt install zfsutils-linux -y
sudo zpool create zfspv-pool $ZFSDISK

##########################################################################################################################
#if you want to be sure, reboot and check if the zpool is autodiscovered
##########################################################################################################################

sudo zpool status


# you need to login to activate group activity, this way we kind of bypass that completely
sudo su $(whoami) -c "microk8s config > ~/.kube/config"
chmod 600 .kube/config


KUBENODE=$(kubectl get node -o json | jq '.items[] | .metadata.name' -r)
echo "################## Kubectl working on $KUBENODE"

#topology label for openebs
kubectl label node $KUBENODE openebs.io/rack=rack1



#some microk8s ninja editing
wget https://openebs.github.io/charts/zfs-operator.yaml
cat zfs-operator.yaml | sed  's#/var/lib/kubelet/#/var/snap/microk8s/common/var/lib/kubelet/#g' > zfs-operator-microk8s.yaml
kubectl apply -f zfs-operator-microk8s.yaml

#unless you enabled storage
#kubectl patch storageclass microk8s-hostpath -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
cat <<EOF  | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: openebs-zfspv
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
parameters:
  recordsize: "4k"
  compression: "off"
  dedup: "off"
  fstype: "zfs"
  poolname: "zfspv-pool"
provisioner: zfs.csi.openebs.io
EOF

#verify if zfspv is now the default
echo "################## Checking if class is available"
kubectl get sc


cat <<EOF | kubectl apply -f -
kind: VolumeSnapshotClass
apiVersion: snapshot.storage.k8s.io/v1
metadata:
  name: zfspv-snapclass
  annotations:
    snapshot.storage.kubernetes.io/is-default-class: "true"
    k10.kasten.io/is-snapshot-class: "true"
driver: zfs.csi.openebs.io
deletionPolicy: Delete
EOF


#try out a volume
cat <<EOF | kubectl apply -f -
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: csi-zfspv
spec:
  storageClassName: openebs-zfspv
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 4Gi
EOF
while [ $(kubectl get pvc csi-zfspv -o json | jq ".status.phase" -r) != "Bound" ]; do sleep 1;echo "waiting for bound status"; done
echo "################## This should output a pvc"
kubectl get pvc
sleep 1
kubectl delete $(kubectl get pvc -o name)


helm repo add kasten https://charts.kasten.io/
kubectl create namespace kasten-io

if [ $KASTENTOKENAUTH -eq 1 ]
then
echo "################# CONFIGURING TOKENAUTH"
helm install k10 kasten/k10 --namespace=kasten-io --set externalGateway.create=true --set auth.tokenAuth.enabled=true --set optionalColocatedServices.vbrintegrationapi.enabled=true
kubectl create serviceaccount login-sa --namespace kasten-io
else
echo "################# CONFIGURING BASICAUTH"
helm install k10 kasten/k10 --namespace=kasten-io --set externalGateway.create=true --set auth.basicAuth.enabled=true \
--set auth.basicAuth.htpasswd="$(cat auth)"
fi




#helm uninstall k10 --namespace=kasten-io

#get your service ip
echo "################## Kasten should be online"
kubectl get svc -n kasten-io gateway-ext


#adding minios3
#admin:notsecure
cat <<'EOF' > ~/minios3.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: minios3
---
apiVersion: v1
kind: Service
metadata:
  name: minios3
  labels:
    app: minios3
  namespace: minios3
spec:
  ports:
  - port: 80
    targetPort: 80
    name: minios3api
  - port: 9001
    targetPort: 9001
    name: minios3console
  type: LoadBalancer
  selector:
    app: minios3
---
apiVersion: v1
kind: Secret
metadata:
  name: minio-secret
  namespace: minios3
type: Opaque
data:
  minio-root-password: bm90c2VjdXJl
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: minios3
  namespace: minios3
spec:
  serviceName: "minios3"
  replicas: 1
  selector:
    matchLabels:
      app: minios3
  template:
    metadata:
      labels:
        app: minios3
    spec:
      containers:
      - name: minios3
        image: minio/minio
        args: ["server","/data","--address",":80","--console-address",":9001"]
        env:
 #           - name: MINIO_ROOT_USER
 #             value: admin
 #           - name: MINIO_REGION_NAME
 #             value: us-east-1
 #           - name: MINIO_ROOT_PASSWORD
 #             valueFrom:
 #               secretKeyRef:
 #                 key: minio-root-password
 #                 name: minio-secret
        ports:
        - containerPort: 80
          name: minios3api
        - containerPort: 9001
          name: minios3console
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 10Gi
EOF
sed -i "s/bm90c2VjdXJl/$(echo $S3AUTH | base64)/" ~/minios3.yaml
kubectl apply -f ~/minios3.yaml
sleep 30
#kubectl -n minios3 wait --for=condition=ready pod/minios3-0 --timeout=180s
#kubectl logs minios3-0 -n minios3
echo "################## Minio should be online"
kubectl get svc -n minios3


# CREATE USER, BUCKET AND APPLY RW POLICY IN MINIO + CREATE INFRASTRUCTURE PROFILE IN K10
SECONDIP=${FIRSTIP%.*}.$((${FIRSTIP##*.}+1))

wget https://dl.min.io/client/mc/release/linux-amd64/mc
sudo mv mc /usr/local/bin/
sudo chmod +x /usr/local/bin/mc

mc alias set minios3 http://$SECONDIP minioadmin minioadmin --api S3v4
mc admin user add minios3 $user $access_key
mc admin user svcacct add --access-key "$access_key" --secret-key "$secret_key" minios3 $user
mc mb minios3/$bucket
# mc admin policy set minios3 readwrite user=$user
mc admin policy attach minios3 readwrite --user $user

kubectl create secret generic k10-minios3-secret \
      --namespace kasten-io \
      --type secrets.kanister.io/aws \
      --from-literal=aws_access_key_id=$access_key \
      --from-literal=aws_secret_access_key=$secret_key

cat <<EOF >>minios3-$bucket-bucket.yaml
apiVersion: config.kio.kasten.io/v1alpha1
kind: Profile
metadata:
  name: minio-k8s
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
      name: minios3-k10-bucket
      objectStoreType: S3
      endpoint: 'http://$SECONDIP'
      skipSSLVerify: true
      name: k10
      region: nl-home-lab-1
EOF

kubectl apply -f minios3-$bucket-bucket.yaml
echo


helm repo add bitnami https://charts.bitnami.com/bitnami
kubectl create namespace mysql-demo
helm install mysql-demo bitnami/mysql --namespace=mysql-demo

kubectl -n mysql-demo apply -f https://raw.githubusercontent.com/tdewin/mysql-employees/main/configmap.yaml
kubectl -n mysql-demo apply -f https://raw.githubusercontent.com/tdewin/mysql-employees/main/deployment.yaml
kubectl -n mysql-demo apply -f https://raw.githubusercontent.com/tdewin/mysql-employees/main/svc.yaml

sleep 15
kubectl -n mysql-demo wait --for=condition=ready pod/mysql-demo-0 --timeout=180s
kubectl -n mysql-demo get pod

kubectl -n mysql-demo apply -f https://raw.githubusercontent.com/tdewin/mysql-employees/main/initjob.yaml

kubectl create secret generic basic-auth --from-file=auth -n mysql-demo





echo "################## Fake application should be online"
kubectl -n mysql-demo get svc




cat << 'EOF' | kubectl -n mysql-demo apply -f -
apiVersion: v1
data:
  auth: YWRtaW46JGFwcjEkdXNPbWV3MlIkUTZsNklnMUVVZml1a3diVHYuTGJ1Lgo=
kind: Secret
metadata:
  name: basic-auth
type: Opaque
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mysql-employees-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required - foo'
spec:
  rules:
  - http:
      paths:
      - path: /employees(/|$)(.*)
        pathType: Prefix
        backend:
          serviceName: mysql-employees-svc
          servicePort: 80
EOF
sleep 15
echo "################## Trying out ingress"
kubectl get ingress -n mysql-demo


# kubernetes dashboard  
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
kubectl create ns kubernetes-dashboard
helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard -n kubernetes-dashboard --set=service.type=LoadBalancer

# wordpress with custom theme
helm install wordpress bitnami/wordpress --create-namespace --namespace wordpress
echo;echo "Initializing Wordpress and applying custom theme" && sleep 120
kubectl exec -it $(kubectl get pod --namespace=wordpress | grep wordpress | awk '{print $1}' | sed '/mariadb/d') -n wordpress -- bash -c "wp theme install https://downloads.wordpress.org/theme/vantage.1.20.4.zip"
kubectl exec -it $(kubectl get pod --namespace=wordpress | grep wordpress | awk '{print $1}' | sed '/mariadb/d') -n wordpress -- bash -c "wp theme activate vantage"
kubectl exec -it $(kubectl get pod --namespace=wordpress | grep wordpress | awk '{print $1}' | sed '/mariadb/d') -n wordpress -- bash -c "wp option update blogname 'My Veeam|Kasten K10 Blog'"


# adguard-home
helm repo add k8s-at-home https://k8s-at-home.com/charts/
helm repo update
helm install adguard-home k8s-at-home/adguard-home --create-namespace --namespace adguard-home
#kubectl patch svc adguard-home --namespace=adguard-home -p '{"spec": {"type": "LoadBalancer", "externalIPs":["'$LASTIP'"]}}'
FIFTHIP=${FIRSTIP%.*}.$((${FIRSTIP##*.}+5))
kubectl patch svc adguard-home --namespace=adguard-home -p '{"spec": {"type": "LoadBalancer", "externalIPs":["'$FIFTHIP'"]}}' && sleep 20
kubectl patch svc adguard-home-dns-tcp --namespace=adguard-home -p '{"spec": {"type": "LoadBalancer", "externalIPs":["'$FIFTHIP'"]}}' && sleep 20
kubectl patch svc adguard-home-dns-udp --namespace=adguard-home -p '{"spec": {"type": "LoadBalancer", "externalIPs":["'$FIFTHIP'"]}}' && sleep 10


echo;echo "Creating Backup Policies..."
wget https://raw.githubusercontent.com/marcnl/linux/main/k8s/create_backup_policies.sh
chmod +x ./create_backup_policies.sh
./create_backup_policies.sh
echo

echo;echo "Creating Backup Presets..."
wget https://raw.githubusercontent.com/marcnl/linux/main/k8s/create_presets.sh
chmod +x ./create_presets.sh
./create_presets.sh
echo


cat << 'EOF' >  ~/getdashboardtoken.sh
#SECRETNAME=$(kubectl get sa -n kubernetes-dashboard kubernetes-dashboard -o jsonpath={.secrets[0].name})
#TOKEN=$(kubectl get secret -n kubernetes-dashboard $SECRETNAME -o jsonpath={.data.token}| base64 -d)
TOKEN=$(kubectl create token login-sa --namespace=kasten-io)
printf "\n$TOKEN\n"
echo
EOF
chmod +x  ~/getdashboardtoken.sh


## Creating permanant token for login-sa to connect to VBR 
#desired_token_secret_name=login-sa-vbrtoken
kubectl apply --namespace=kasten-io --filename=- <<EOF
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: login-sa-vbrtoken
  annotations:
    kubernetes.io/service-account.name: "login-sa"
EOF
cat << 'EOF' >  ~/vbrtoken.sh
kubectl get secret login-sa-vbrtoken --namespace kasten-io -ojsonpath="{.data.token}" | base64 --decode; echo;
EOF
chmod +x  ~/vbrtoken.sh


# Enable K10 reporting
cat > enable-reporting-policy.yaml <<EOF
kind: Policy
apiVersion: config.kio.kasten.io/v1alpha1
metadata:
  name: k10-system-reports-policy
  namespace: kasten-io
  managedFields:
    - manager: controllermanager-server
      operation: Update
      apiVersion: config.kio.kasten.io/v1alpha1
      fieldsType: FieldsV1
      fieldsV1:
        f:status:
          f:hash: {}
          f:specModifiedTime: {}
          f:validation: {}
    - manager: dashboardbff-server
      operation: Update
      apiVersion: config.kio.kasten.io/v1alpha1
      fieldsType: FieldsV1
      fieldsV1:
        f:spec:
          .: {}
          f:actions: {}
          f:comment: {}
          f:createdBy: {}
          f:frequency: {}
          f:lastModifyHash: {}
          f:selector: {}
        f:status: {}
spec:
  comment: The policy for enabling auto-generated reports.
  frequency: "@daily"
  selector: {}
  actions:
    - action: report
      reportParameters:
        statsIntervalDays: 1
  createdBy: kasten-io:login-sa
EOF

kubectl apply -f enable-reporting-policy.yaml


echo && echo
echo "#### IP Addresses and login details #### "
#buggy access
#echo "Minio : admin and password you supplied / Internal DNS http://minios3.minios3 region us-east-1 bucket minios3 "
echo

echo "### External IP's for all services:"
#kubectl get services --all-namespaces -o json | jq -r '.items[] | { name: .metadata.name, ns: .metadata.namespace, ip: .status.loadBalancer?|.ingress[]?|.ip  }'
kubectl get svc -A | grep LoadBalancer
echo && echo

echo "- Kasten K10: Use ~/getdashboardtoken.sh to get token for Kasten K10 dashboard (http://$FIRSTIP/k10/)"
echo "- Minio S3: minioadmin:minioadmin (http://${FIRSTIP%.*}.$((${FIRSTIP##*.}+1)):9001)"
echo "- MySQL demo: No login required (http://${FIRSTIP%.*}.$((${FIRSTIP##*.}+2)))"
echo "- Kubernetes: Use ~/getdashboardtoken.sh to get token for Kubernetes dashboard (https://${FIRSTIP%.*}.$((${FIRSTIP##*.}+3)))"
echo "- Wordpress: user:$(kubectl get secret --namespace wordpress wordpress -o jsonpath="{.data.wordpress-password}" | base64 -d) (admin login: https://${FIRSTIP%.*}.$((${FIRSTIP##*.}+4))/admin)"
echo "- AdGuard Home: No login required (http://${FIRSTIP%.*}.$((${FIRSTIP##*.}+5)):3000)"
echo
echo "Give the installed services a couple of minutes to start."
echo

echo "Installed versions:"
echo "- Ubuntu: $(lsb_release -sr)"
echo "- $(sudo microk8s version)"
echo "- Kubectx: $(/bin/kubectx --version)"
echo "- Kubens: $(/bin/kubens --version)"
echo "- Helm: $(helm version --short)"
echo


# Clean up
rm -Rf ./linux-amd64
mkdir yaml
mv *.yaml ./yaml
echo

echo "Run the following command to download the create_profiles script to easily connect external MinIO storage, vCenter and VBR:";echo
echo "wget https://raw.githubusercontent.com/marcnl/linux/main/k8s/create_profiles.sh && chmod +x ./create_profiles.sh";echo
echo "Before running the script, edit script to fill in login and configuration details for MinIO, vCenter and VBR.";echo
echo
echo "Do you want to connect Kasten to VBR? Make sure to set the ServerURIScheme Registry Key for HTTP access"
echo "on the VBR Server and run the ~/vbrtoken.sh script to grab the (permanent) token for login-sa"
echo

ELAPSED="Script completed in: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"
echo $ELAPSED
echo
exit


### Below is a Powershell Script to start the whole environment in ###
### your browser and add a login token to the clipboard automatically ###

## RUN THIS ONCE (to automatically login to the K8S VM without using a password (adjust accordingly):
## ssh-keygen -t rsa && scp $home\.ssh\id_rsa.pub marc@k8s.veeam.lab:.ssh/authorized_keys

## Small Powershell script for easy access (adjust URL/IP/user accordingly)
# MicrosoftEdge.exe
#start http://k10.veeam.lab/k10	
#start https://minio-k8s.veeam.lab
#start https://kubernetes.veem.lab
#start http://192.168.1.123
#start https://192.168.1.125
#start http://192.168.1.126:3000
#ssh marc@k8s.veeam.lab '~/getdahboardtoken.sh' | Set-Clipboard
