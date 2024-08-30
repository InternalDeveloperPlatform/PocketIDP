# Pocket IDP

The material in this repo allows you to create an Internal Developer Platform (IDP) running with the Humanitec Platform Orchestrator in less than 5 minutes.
The Pocket IDP is based on the ["Five-minute IDP"](https://developer.humanitec.com/introduction/getting-started/the-five-minute-idp/) getting started guide in the Humanitec developer docs.

However, it has expanded its capabilities to demonstrate end-to-end platform-based flows. Because of that, it can be used to experience how modern platform-building patterns behave in reality without any strings or cloud costs attached.

If you choose to extend your experience beyond the capabilities of a local-machine-solution, for example, to collaborate with others on the same instance, you can simply upgrade to a cloud-based reference-architecture, which are available as OSS Terraform based packages here: [Humanitec Architecture (github.com)](https://github.com/humanitec-architecture/).

## Pre-requisites

- The [humctl](https://developer.humanitec.com/platform-orchestrator/cli/) CLI
- Docker (or an equivalent)
- A Humanitec Organization. If you do not have one yet, [sign up here](https://humanitec.com/free-trial) for a free trial.
- A user account with the [Administrator](https://developer.humanitec.com/platform-orchestrator/security/rbac/#organization-level-roles) role in that Organization
- mkcert &rarr; [mkcert installation](https://github.com/FiloSottile/mkcert?tab=readme-ov-file#installation)
- direnv &rarr; [direnv installation](https://direnv.net/#basic-installation)

## Installation

> [!IMPORTANT]
> The following instructions are meant to be executed on MacOS or Linux. If you use a different shell or > OS, please adopt paths and commands as needed.

1. Create a local CA and sign a certificate that you can provide to the PocketIDP
   
   ```shell
   mkcert -install
   mkcert 5min-idp 5min-idp-control-plane kubernetes.docker.internal localhost 127.0.0.1 ::1
   ```
   
   Be sure to note the path and filenames of the generated certificates as you need them for step 3!

2. Login with humctl to create the token that will be picked up by direnv in the next step
   
   ```shell
   humctl login
   ```
   
   Now follow [this guide](https://developer.humanitec.com/platform-orchestrator/security/service-users/) to create a more permanent service user token that will allow usage of your PocketIDP beyond 24h. You will need it as well in the next step.

3. Populate environment variables
   
   First, you want to create a `.envrc` file with the following contents - it will be run by direnv every time you change into this directory, so it might be a good idea to have your own directory for the PocketIDP.
   
   ```shell
   token=$(yq -r '.token' ~/.humctl)
   export HUMANITEC_TOKEN=$token
   export HUMANITEC_ORG="" #set me to your Humanitec org
   export HUMANITEC_SERVICE_USER="" #set permanent token from step 2
   # CA in PEM format and set here
   export TLS_CA_CERT="$(mkcert -CAROOT)/rootCA.pem"
   # Please check on the paths to your files from step 1
   export TLS_CERT_STRING="$(cat /%%%YOUR PATH HERE%%%/%%%YOUR FILE NAME HERE%%%.pem | base64)" #Your cert in base64 encoded format
   export TLS_KEY_STRING="$(cat /%%%YOUR PATH HERE%%%/%%%YOUR FILE NAME HERE%%%-key.pem | base64)" #Your key in base64 encoded format
   ```
   
   and allow direnv to work with this file by executing
   
   ```shell
   direnv allow
   ```

## Run the PocketIDP

### For the prebuilt container

```shell
docker run --rm -it -h pocketidp --name 5min-idp \
    -e HUMANITEC_ORG \
    -e HUMANITEC_SERVICE_USER \
    -e TLS_CA_CERT \
    -e TLS_CERT_STRING \
    -e TLS_KEY_STRING \
    -v hum-5min-idp:/state \
    -v $HOME/.humctl:/root/.humctl \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --network bridge \
    ghcr.io/internaldeveloperplatform/pocketidp:latest
```

### For the non-prebuilt container

```shell
gh repo clone InternalDeveloperPlatform/PocketIDP
cd PocketIDP
make run-local
```
