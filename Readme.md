# Conteneurs : petite application de démonstration

L'application est un `Hello world` en C, qui va nous servir à montrer différents aspects liés à l'utilisations des conteneurs.

## Développement de l'application

Pour standardiser l'environnement de développement et éviter d'avoir à installer localement la chaîne de compilation C,
l'application est développée dans un conteneur. Le choix fait dans cet exemple est une distribution Ubuntu 24.04 (noble),
customisée par Microsoft.

La configuration de l'environnement peut être adapté en modifiant le fichier [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json).

Pour construire l'application, il suffit alors, dans un terminal de taper :

```bash
make hello
```

ou

```bash
gcc hello.c -o hello 
```

et pour l'utiliser:

```bash
./hello # --> Hello World !
./hello Jeanne # --> Hello Jeanne !
```

## Conteneurisation de l'application

### Ajout d'un *Dockerfile*

Pour distribuer plus facilement l'application, il a également été décidé d'en faire une version conteneurisée.
Les étapes de constructions de l'image sont définies dans le fichier [Dockerfile](./Dockerfile).

Dans notre cas la construction se fait en 2 phases :

La première phase utilise une image [gcc](https://hub.docker.com/_/gcc) pour construire l'application (compilation statique de l'exécutable) :

```Dockerfile
FROM docker.io/library/gcc:15 AS build
COPY ./hello.c /src/
WORKDIR /src/
RUN gcc -static -o hello hello.c
```

La seconde phase, crée l'image finale contenant l'exécutable et définit la commande à utiliser pour démarrer le conteneur :

```Dockerfile
FROM scratch AS prod
COPY --from=build /src/hello /bin/hello
ENTRYPOINT [ "/bin/hello" ]
CMD [ "USMB" ]
```

### Construction de l'image

Pour construire l'image il suffit d'utiliser la commande [docker build](https://docs.docker.com/reference/cli/docker/buildx/build/) :

```bash
docker build --tag stalb/hello:utltra-slim .
``` 

On peut alors utiliser l'image construite :

```bash
docker run stalb/hello:utltra-slim      # --> Hello USMB !
docker run stalb/hello:utltra-slim Joe  # --> Hello Joe !
```

### Téléchargement vers [Docker Hub](https://hub.docker.com/explore)

Pour mettre l'image sur un *registry docker*, on peut utiliser la commande [docker push](https://docs.docker.com/reference/cli/docker/image/push/).

```bash
docker push stalb/hello:utltra-slim
```

L'image peut alors être téléchargée depuis le dépôt Docker Hub : `docker pull stalb/hello:utltra-slim`

<ins>Remarque :</ins>  
Pour pouvoir utiliser la commande `docker push`, il faut préalablement s'être authentifié auprès du *registry docker* en utilisant la commande [docker login](https://docs.docker.com/reference/cli/docker/login/).

## Pipelines GitLab et GitHub

La plupart des hébergeurs git (Gilab/GitHub/BitBucket/etc.), permettent maintenant de construire,
tester et déployer (par exemple sous forme de paquet logiciel) les projets hébergés, à chaque
fois qu'une nouvelle version est poussée sur le dépôt git.

### [Pipeline GitLab](https://docs.gitlab.com/ci/pipelines/)

Chez GitLab cela se fait typiquement en ajoutant un fichier [.gilab-ci.yml](.gilab-ci.yml) à la racine du projet git.

Dans notre cas, le *pipeline* comprends 3 étapes.

Une première étape de construction de l'application (l'exécutable *hello*). Elle utilise pour cela, une image docker gcc.

```yaml
build:
  image: gcc:15.2.0-trixie
  stage: build
  script:
    - make hello
  artifacts:
    paths:
      - hello
```

La deuxième étape teste l'application, afin de vérifier qu'elle fonctionne comme prévu.
Elle utilise à cet effet une image Debian, dans laquelle l'exécutable construit à la première étape,
va être utilisé plusieurs fois.

```yaml
test:
  image: debian:13-slim
  stage: test
  script:
    - ./hello && test "$(./hello)" = "Hello World !"
    - ./hello Joe && test "$(./hello Joe)" = "Hello Joe !"
  needs:
    - job: build
      artifacts: true
```

La troisième étape permet de construire l'image docker et de la pousser vers le `registry docker` fourni par GitLab.
Cette étape est déclinée en deux versions, une version qui utilise [docker](https://docs.docker.com/engine/)
et une seconde qui utilise [podman](https://podman.io/).

```yaml
build-image:
  image: docker:29.2.1-cli
  stage: images
  services:
    - docker:29.2.1-dind
  script:
    - docker login -u ${CI_REGISTRY_USER} -p ${CI_REGISTRY_PASSWORD} ${CI_REGISTRY}
    - docker build
        -t ${CI_REGISTRY_IMAGE}:${CI_COMMIT_REF_NAME}-docker
        --target prod .
    - docker push ${CI_REGISTRY_IMAGE}:${CI_COMMIT_REF_NAME}-docker
  only:
    - main
    - tags

build-image-alt:
  image: quay.io/containers/buildah:v1.42.2-immutable
  stage: images
  script:
    - buildah login -u ${CI_REGISTRY_USER} -p ${CI_REGISTRY_PASSWORD} ${CI_REGISTRY}
    - buildah build
        -t ${CI_REGISTRY_IMAGE}:${CI_COMMIT_REF_NAME}-buildah
        --format docker
        --target prod .
    - buildah push ${CI_REGISTRY_IMAGE}:${CI_COMMIT_REF_NAME}-buildah
  only:
    - main
    - tags

```

Les images construites sont alors disponibles dans le registry local du dépôt :

```bash
docker pull registry.gitlab.com/i609-docker/hello:main-docker
docker run registry.gitlab.com/i609-docker/hello:main-docker    # --> Hello USMB !

docker pull registry.gitlab.com/i609-docker/hello:main-buildah
docker run registry.gitlab.com/i609-docker/hello:main-buildah   # --> Hello USMB !
```

### Pipeline GitHub

On peut faire la même chose sur *GitHub* en utilisant des [GitHub Actions](https://github.com/features/actions).

Pour plus de détails dans regarder les fichiers [.github/workflows/cc-build.yml](.github/workflows/cc-build.yml) et
[.github/workflows/docker-publish.yml](.github/workflows/docker-publish.yml).

Comme pour Gilab images construites sont alors disponibles dans le registry local du dépôt GitHub :

```bash
docker pull ghcr.io/i609-docker/hello:main
docker run ghcr.io/i609-docker/hello:main    # --> Hello USMB !
```

## Pour aller plus loin

* Documentation client **docker** : <https://docs.docker.com/engine/reference/commandline/cli/>
* Documentation **podman** : <https://docs.podman.io/en/latest/>
* Documentation fichier **Dockerfile** : <https://docs.docker.com/engine/reference/builder/>
* Socumentation commande **docker compose** : <https://docs.docker.com/compose/reference/>
* Spécification fichier **compose.yaml** : <https://github.com/compose-spec/compose-spec/blob/master/spec.md>
* Tutoriel sur la *conteneurisation* (et bien plus...) en français : <https://blog.stephane-robert.info/docs/conteneurs/introduction/>
* Piplelines GitLab : <https://docs.gitlab.com/ci/yaml/>
* Github Actions : <https://github.com/features/actions>
