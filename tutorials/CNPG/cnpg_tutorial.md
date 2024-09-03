# CNPG... or simulating DBaaS with your PocketIDP

## Scenario

1. Imagine that you have a department in your company that offers DBaaS

2. They have built an interface that allows you to order a new PostgreSQL cluster and database by putting custom resources onto a Kubernetes cluster

3. You now want to utilize this interface and integrate it into your platform to make it easy for developers to actually get DBaaS instances

The underlying pattern is, that you want to enable the self-service vending machine that is your platform to also offer databases. But not just any, like from a cloud provider, but your own company's service. This is not an easy feat if you're not having the right abstraction to the interfaces in question.

## Install

Install the CNPG operator to simulate the interface of your DBaaS department

```shell
kubectl apply --server-side -f \
https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.23/releases/cnpg-1.23.1.yaml
```

## Configure

Now, you need to connect the interface to your orchestrator, so that abstract asks for infrastructure will be answered in the right way. For this, you need to configure the orchestrator by replacing the current resource definition for Postgres with a new one that is using the interface.

CNPG needs two manifests to be in place for a cluster to be successfully provisioned.

### Cluster

This Kubernetes manifest will create a new cluster if present on a Kubernetes cluster that has CNPG installed and active.

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: my-cluster
spec:
  instances: 1

  storage:
    size: 100M
  bootstrap:
    initdb:
      database: my-cluster
      owner: scott
      secret:
        name: my-cluster-secret
```

### Secret

The manifest for the secret specifies the credentials needed to log on to the new database. It is referenced by the cluster `my-cluster-secret`.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-cluster-secret
type: kubernetes.io/basic-auth
data:
  username: scott
  password: tiger
```

### Resource Definition

  As this is the configuration code for the orchestrator, it is rather product-specific. If you want to learn how to do this, [this](https://developer.humanitec.com/platform-orchestrator/resources/resource-definitions/) is a great place to start learning. If you want to progress with the installation, then here is a finished definition - please adjust the 4 letters used in the IDs and name to the one you have in your PocketIDP. E.g. change `5min-idp-uzzq-postgres` to `5min-idp-abcd-postgres`. You can save that file under any name you like.

```yaml
apiVersion: entity.humanitec.io/v1b1
kind: Definition
metadata:
  id: 5min-idp-uzzq-postgres
entity:
  name: 5min-idp-uzzq-postgres
  type: postgres
  driver_type: humanitec/template
  driver_inputs:
    values:
      templates:
        init: |-
          name: my-cluster
          secret: my-cluster-secret
          port: 5432
          user: scott
          password: tiger
        manifests: |-
          secret.yaml:
            location: namespace
            data:
              apiVersion: v1
              kind: Secret
              metadata:
                name: {{ .init.secret }}
              type: kubernetes.io/basic-auth
              data:
                username: {{ .init.user | b64enc }}
                password: {{ .init.password | b64enc }}
          pgcluster.yaml:
            location: namespace
            data:
              apiVersion: postgresql.cnpg.io/v1
              kind: Cluster
              metadata:
                name: {{ .init.name }}
              spec:
                instances: 1
                storage:
                  size: 100M
                bootstrap:
                  initdb:
                    database: {{ .init.name }}
                    owner: {{ .init.user }}
                    secret:
                      name: {{ .init.secret }}
                monitoring:
                  enablePodMonitor: true
        outputs: |
          host: {{ .init.name }}-rw
          name: {{ .init.name }}
          port: {{ .init.port }}
        secrets: |
          username: {{ .init.user }}
          password: {{ .init.password }}
  criteria:
    - app_id: 5min-idp-uzzq
      class: default
```

  You can see how this template includes all necessary manifest code to create the cluster, the database and the secret needed. It also includes the meta information to connect it to the right moving parts in the orchestrator. The driver which will turn the template into manifests that get deployed. The inputs and outputs which turn the template into a concrete instance are provided.

To use the new resource definition instead of the old one, all you need to do is run

```shell
humctl apply -f %%%yourFileNameHere%%%
```

## Use in deployment

Simply re-deploying your test application using the `1_demo.sh` script should change the Postgres from an in-cluster Postgres container to a CNPG-based Postgres cluster.

To check you can use this command - the output should read `my-cluster-rw`

```shell
humctl get active-resource --app 5min-idp-uzzq --env 5min-local -o yaml | yq '.[] | select (.metadata.type == "postgres") | .status.resource.host'
```
