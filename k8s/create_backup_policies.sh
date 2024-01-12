#!/bin/sh

echo "Creating backup policies...";echo

cat > adguardhome-backup-policy.yaml <<EOF
apiVersion: config.kio.kasten.io/v1alpha1
kind: Policy
metadata:
  name: adguardhome-backup-policy
  namespace: kasten-io
spec:
  comment: AdGuard Home backup policy
  frequency: '@daily'
  retention:
    hourly: 0
    daily: 2
  actions:
  - action: backup
  selector:
    matchLabels:
      k10.kasten.io/appNamespace: adguard-home
EOF

kubectl apply -f adguardhome-backup-policy.yaml


cat > kubernetes-dashboard-backup-policy.yaml <<EOF
apiVersion: config.kio.kasten.io/v1alpha1
kind: Policy
metadata:
  name: kubernetes-dashboard-backup-policy
  namespace: kasten-io
spec:
  comment: kubernetes-dashboard backup policy
  frequency: '@daily'
  retention:
    hourly: 0
    daily: 2
  actions:
  - action: backup
  selector:
    matchLabels:
      k10.kasten.io/appNamespace: kubernetes-dashboard
EOF

kubectl apply -f kubernetes-dashboard-backup-policy.yaml


#cat > mysql-demo-backup-policy.yaml <<EOF
#apiVersion: config.kio.kasten.io/v1alpha1
#kind: Policy
#metadata:
#  name: mysql-demo-backup-policy
#  namespace: kasten-io
#spec:
#  comment: MySQL demo backup policy
#  frequency: '@daily'
#  retention:
#    hourly: 0
#    daily: 2
#  actions:
#  - action: backup
#  selector:
#    matchLabels:
#      k10.kasten.io/appNamespace: mysql-demo
#EOF

#kubectl apply -f mysql-demo-backup-policy.yaml


cat > mysql-demo-backup-policy.yaml <<EOF
apiVersion: config.kio.kasten.io/v1alpha1
kind: Policy
metadata:
  name: mysql-demo-backup-policy
  namespace: kasten-io
spec:
  comment: MySQL Demo advanced backup policy
  frequency: '@daily'
  subFrequency:
    weekdays: [5]
    days: [15]
  backupWindow:
    start:
      hour: 22
      minute: 30
    end:
      hour: 7
  retention:
    daily: 14
    weekly: 4
    monthly: 6
  actions:
  - action: backup
  - action: export
    exportParameters:
      frequency: '@monthly'
      profile:
        name: minio-k8s
        namespace: kasten-io
      exportData:
        enabled: true
    retention:
      monthly: 12
      yearly: 5
  selector:
    matchLabels:
      k10.kasten.io/appNamespace: mysql-demo
EOF

kubectl apply -f mysql-demo-backup-policy.yaml


<<com
echo "Create DR policy...";echo

kubectl create secret generic k10-dr-secret \
   --namespace kasten-io \
   --from-literal key='1q2w3e4r5t6y7u8i9o0p'

cat > dr-policy.yaml <<EOF
kind: Policy
apiVersion: config.kio.kasten.io/v1alpha1
metadata:
  name: k10-disaster-recovery-policy
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
          f:createdBy: {}
          f:frequency: {}
          f:lastModifyHash: {}
          f:retention:
            .: {}
            f:daily: {}
            f:hourly: {}
            f:monthly: {}
            f:weekly: {}
            f:yearly: {}
          f:selector:
            .: {}
            f:matchExpressions: {}
        f:status: {}
spec:
  frequency: "@hourly"
  retention:
    hourly: 4
    daily: 1
    weekly: 1
    monthly: 1
    yearly: 1
  selector:
    matchExpressions:
      - key: k10.kasten.io/appNamespace
        operator: In
        values:
          - kasten-io
  actions:
    - action: backup
      backupParameters:
        filters: {}
        profile:
          name: minio-k8s
          namespace: kasten-io
  createdBy: kasten-io:login-sa
EOF

kubectl apply -f dr-policy.yaml
com


echo "Run backup policies...";echo

cat > run-mysql-demo-backup.yaml <<EOF
apiVersion: actions.kio.kasten.io/v1alpha1
kind: RunAction
metadata:
  generateName: run-mysql-demo-backup-policy
spec:
  subject:
    kind: Policy
    name: mysql-demo-backup-policy
    namespace: kasten-io
EOF

kubectl create -f run-mysql-demo-backup.yaml


cat > run-adguardhome-backup.yaml <<EOF
apiVersion: actions.kio.kasten.io/v1alpha1
kind: RunAction
metadata:
  generateName: run-adguardhome-backup-policy
spec:
  subject:
    kind: Policy
    name: adguardhome-backup-policy
    namespace: kasten-io
EOF

kubectl create -f run-adguardhome-backup.yaml


cat > run-kubernetes-dashboard-backup.yaml <<EOF
apiVersion: actions.kio.kasten.io/v1alpha1
kind: RunAction
metadata:
  generateName: run-kubernetes-dashboard-backup-policy
spec:
  subject:
    kind: Policy
    name: kubernetes-dashboard-backup-policy
    namespace: kasten-io
EOF

kubectl create -f run-kubernetes-dashboard-backup.yaml


mv *-backup-policy.yaml run-*.yaml dr-policy.yaml ./yaml/

