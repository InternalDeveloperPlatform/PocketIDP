# Pocket IDP

The material in this repo allows you to create an Internal Developer Platform (IDP) running with the Humanitec Platform Orchestrator in less than 5 minutes.
The Pocket IDP is based on the ["Five-minute IDP"](https://developer.humanitec.com/introduction/getting-started/the-five-minute-idp/) getting started guide in the Humanitec developer docs. Please refer to that guide for additional usage instructions.

For the pocket IDP you need to prepare a few more things on top of the 5min-IDP flow.

1. Create a local CA and sign a certificate that you can provide

    See [mkcert installation](https://github.com/FiloSottile/mkcert?tab=readme-ov-file#installation)
    ```shell
    brew install mkcert 
    mkcert -install
    mkcert 5min-idp 5min-idp-control-plane kubernetes.docker.internal localhost 127.0.0.1 ::1
    ```

2. Populate environment variables

    See [direnv installation](https://direnv.net/#basic-installation)

    ```shell
    brew install direnv
    HUMANITEC_ORG="" #set me
	HUMANITEC_SERVICE_USER="" #set token 
	TLS_CA_CERT="" #Export CA in PEM format and set here
	TLS_CERT_STRING="" #Your cert in base64 encoded format
	TLS_KEY_STRING="" #Your key in base64 encoded format
    humctl login
    direnv allow
    ```

3. Run the PocketIDP

    ```shell
    #For the prebuilt container
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
    
    #For the non-prebuilt container
    gh repo clone InternalDeveloperPlatform/PocketIDP
    cd PocketIDP
    make run-local
    ```
