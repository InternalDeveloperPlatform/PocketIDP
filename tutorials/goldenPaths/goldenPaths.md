# Golden Paths

> [!TIP]
> ...or the art of paving paths that lead to value without any detours

## Scenario

Imagine that you have your PocketIDP at the ready and have learned about how to triage golden paths and also force rank them to get an idea where it makes sense to start your implementation journey.

To have a good idea of how a well implemented golden path feels, you set forth to explore some workflows in the PocketIDP.

## The Paths

### 1. Scaffolding - starting a new project or product

#### Preparation

To enable this golden path, your PocketIDP needs some preparation. Please go to [Your local Gitea instance](https://git.localhost:30443) and login with the credentials 5minadmin/5minadmin .

Be sure to never expose your PocketIDP to the outside as the credentials are all of the same questionable quality!

Navigate to your Backstage repository [here](https://git.localhost:30443/5minorg/backstage) and scroll all the way down to the displayed README.md. There should be a `pencil` icon in the top-right of the box that you want to click. Append any kind of text you like to the end and push the `Commit Changes` button.

This will activate the CI pipeline and deploy your Backstage instance. You need to wait until this is finished - a good indication is the pipeline state you can see under `Actions`.

#### Follow the path

Open your Backstage instance - the link can be discovered in your Humanitec account [here](https://app.humanitec.io/). Locate the Application with the name `5min-backstage-uzzq` - the last four characters might be different in your setup as they're auto-generated. The URL is inside the 5min-local environment. You will have to add the port `:30443` at the end for it to work in your browser.

Inside Backstage you want to push the blue `CREATE` button and choose the `5min Podinfo Service Template`. Follow the scaffolding workflow, providing the necessary `name` as input.

This will create

- the application in your Humanitec org

- the git repo in Gitea, including the CI pipeline and workload code

- the entry in the Backstage catalog 

Follow the link to the `repository`.

> [!IMPORTANT]
> It might be that your local DNS configuration is not picking up the domain under which
> some links are generated inside the PocketIDP. If that is the case, please edit your
> `/etc/hosts` file (or Windows equivalent) and map `5min-idp-control-plane` to `127.0.0.1`.

### 2. Adding resources

#### Preparation

If you followed the preceding path to this point, you're all set. If not, you need to locate and enter the repository.

#### Follow the path

Inside the repository, you can go to `score.yaml` (click on it) and edit it (using the `pencil` icon).

It is your goal to add a resource and this is easily achieved by adding these lines to the `resources` section of the YAML.

```yaml
  posty:
    type: postgres
```

Feel free to change the name `posty` to your liking but keep the type as it is as they're pre-defined interfaces.

The final file should look like this

```yaml
apiVersion: score.dev/v1b1

metadata:
  name: podinfo-workload

service:
  ports:
    www:
      port: 80 # The port that the service will be exposed on
      targetPort: 9898 # The port that the container will be listening on

containers:
  podinfo:
    image: . # Set by pipeline
    variables:
      Hello: World

resources:
  dns: # We need a DNS record to point to the service 
    type: dns
  posty:
    type: postgres
  route:
    type: route
    params:
      host: ${resources.dns.host}
      path: /
      port: 80
```

Push the `Commit Changes` button at the bottom - which will commit this directly to the main branch. It's fine for now.

This will activate the CI pipeline again and deploy a new version of your code, including the desired Postgres database. It is **that easy** to add resources with a platform that has paved such a golden path for developers.

You can check on the existence and properties of the database in the orchestrator. Locate your App &rarr; environment &rarr; deployment &rarr; workload &rarr; resource.

### 3. Daily deployments, including changes in configuration

#### Preparation

If you followed the preceding path to this point, you're all set. If not, you need to locate and enter the repository.

#### Follow the path

Inside the repository, you can go to `score.yaml` (click on it) and edit it (using the `pencil` icon).

It is your goal to add the missing connection string as app configuration. This is easily achieved by adding this line to the `containers -> Variables` section of the YAML.

```yaml
      connection_string: ${resources.posty.username}:${resources.posty.password}@${resources.posty.host}:${resources.posty.port}/${resources.posty.name}
```

This will use the contained replacers to forward the information that the orchestrator holds after creating the database into the runtime variable that the app can observe while running. It will allow the app to self-configure from the context and connect to the right database every time.

The final score.yaml should look like this

```yaml
apiVersion: score.dev/v1b1

metadata:
  name: podinfo-workload

service:
  ports:
    www:
      port: 80 # The port that the service will be exposed on
      targetPort: 9898 # The port that the container will be listening on

containers:
  podinfo:
    image: . # Set by pipeline
    variables:
      Hello: World
      connection_string: ${resources.posty.username}:${resources.posty.password}@${resources.posty.host}:${resources.posty.port}/${resources.posty.name}

resources:
  dns: # We need a DNS record to point to the service 
    type: dns
  posty:
    type: postgres
  route:
    type: route
    params:
      host: ${resources.dns.host}
      path: /
      port: 80
```

> [!WARNING]
> This path ends **exactly** here, to trigger the next one. Golden paths can
> sometimes be combined/composed elegantly to achieve different outcomes, which is
> what we do in this case.

### 4. Spinning up ephemeral environments

### Preparation

If you followed the preceding path to this point, you're all set. If not, you need to execute path number 3 first!

#### Follow the path

Scroll to the bottom of the page, locate the `Create a new branch for this commit and start a pull request` option, and select it. The branch name doesn't matter - feel free to change if you want.

Push the `Propose file change` button.

Push the `New Pull Request` button.

Push the `Create Pull Request` button.

Wait until the CI pipeline has run to completion - you can check on the state under `Actions`.

Locate your app in the Humanitec UI [here](https://app.humanitec.io/). Observe how using the pull request flow has created a discrete environment (most probably named `PR-1`, the number depends on the number of PRs you've created in this Gitea repository), which is ephemeral and only available for the duration of this pull request.

If you feel confident that you've done a good job, go back to the PR in your Gitea repository and push the `Create merge commit` button twice. Push `Delete Branch` and accept with `Yes`.

Observe in the Humanitec UI how the environment is deleted almost instantly, releasing all resources to be used by someone else and stop accruing any cost.
