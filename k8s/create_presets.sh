#!/bin/sh

echo "Create daily and weekly presets..."

cat <<EOF >>daily-preset.yaml
kind: PolicyPreset
apiVersion: config.kio.kasten.io/v1alpha1
metadata:
  name: daily
  namespace: kasten-io
  resourceVersion: "7371"
  generation: 2
  managedFields:
    - manager: controllermanager-server
      operation: Update
      apiVersion: config.kio.kasten.io/v1alpha1
      fieldsType: FieldsV1
      fieldsV1:
        f:status:
          .: {}
          f:type: {}
          f:validation: {}
      subresource: status
    - manager: dashboardbff-server
      operation: Update
      apiVersion: config.kio.kasten.io/v1alpha1
      fieldsType: FieldsV1
      fieldsV1:
        f:spec:
          .: {}
          f:backup:
            .: {}
            f:backupWindow:
              .: {}
              f:end:
                .: {}
                f:hour: {}
                f:minute: {}
              f:start:
                .: {}
                f:hour: {}
                f:minute: {}
            f:frequency: {}
            f:profile:
              .: {}
              f:name: {}
              f:namespace: {}
            f:retention:
              .: {}
              f:daily: {}
          f:export:
            .: {}
            f:exportData:
              .: {}
              f:enabled: {}
            f:profile:
              .: {}
              f:name: {}
              f:namespace: {}
spec:
  backup:
    frequency: "@daily"
    backupWindow:
      start:
        hour: 0
        minute: 0
      end:
        hour: 5
        minute: 0
    retention:
      daily: 2
    profile:
      name: minio-k8s
      namespace: kasten-io
  export:
    profile:
      name: minio-k8s
      namespace: kasten-io
    exportData:
      enabled: true
EOF

kubectl apply -f daily-preset.yaml

cat <<EOF >>weekly-preset.yaml
kind: PolicyPreset
apiVersion: config.kio.kasten.io/v1alpha1
metadata:
  name: weekly
  namespace: kasten-io
  resourceVersion: "7315"
  generation: 3
  managedFields:
    - manager: controllermanager-server
      operation: Update
      apiVersion: config.kio.kasten.io/v1alpha1
      fieldsType: FieldsV1
      fieldsV1:
        f:status:
          .: {}
          f:type: {}
          f:validation: {}
      subresource: status
    - manager: dashboardbff-server
      operation: Update
      apiVersion: config.kio.kasten.io/v1alpha1
      fieldsType: FieldsV1
      fieldsV1:
        f:spec:
          .: {}
          f:backup:
            .: {}
            f:backupWindow:
              .: {}
              f:end:
                .: {}
                f:hour: {}
                f:minute: {}
              f:start:
                .: {}
                f:hour: {}
                f:minute: {}
            f:frequency: {}
            f:profile:
              .: {}
              f:name: {}
              f:namespace: {}
            f:retention:
              .: {}
              f:weekly: {}
          f:export:
            .: {}
            f:exportData:
              .: {}
              f:enabled: {}
            f:profile:
              .: {}
              f:name: {}
              f:namespace: {}
spec:
  backup:
    frequency: "@weekly"
    backupWindow:
      start:
        hour: 22
        minute: 0
      end:
        hour: 6
        minute: 0
    retention:
      weekly: 2
    profile:
      name: minio-k8s
      namespace: kasten-io
  export:
    profile:
      name: minio-k8s
      namespace: kasten-io
    exportData:
      enabled: true
EOF

kubectl apply -f weekly-preset.yaml


cat <<EOF >>monthly-preset.yaml
kind: PolicyPreset
apiVersion: config.kio.kasten.io/v1alpha1
metadata:
  name: monthly
  namespace: kasten-io
  resourceVersion: "7285"
  generation: 4
  managedFields:
    - manager: controllermanager-server
      operation: Update
      apiVersion: config.kio.kasten.io/v1alpha1
      fieldsType: FieldsV1
      fieldsV1:
        f:status:
          .: {}
          f:type: {}
          f:validation: {}
      subresource: status
    - manager: dashboardbff-server
      operation: Update
      apiVersion: config.kio.kasten.io/v1alpha1
      fieldsType: FieldsV1
      fieldsV1:
        f:spec:
          .: {}
          f:backup:
            .: {}
            f:backupWindow:
              .: {}
              f:end:
                .: {}
                f:hour: {}
                f:minute: {}
              f:start:
                .: {}
                f:hour: {}
                f:minute: {}
            f:frequency: {}
            f:retention:
              .: {}
              f:monthly: {}
          f:export:
            .: {}
            f:exportData:
              .: {}
              f:enabled: {}
            f:profile:
              .: {}
              f:name: {}
              f:namespace: {}
spec:
  backup:
    frequency: "@monthly"
    backupWindow:
      start:
        hour: 22
        minute: 0
      end:
        hour: 6
        minute: 0
    retention:
      monthly: 2
  export:
    profile:
      name: minio-k8s
      namespace: kasten-io
    exportData:
      enabled: true
EOF

kubectl apply -f monthly-preset.yaml


mv *-preset.yaml ./yaml
