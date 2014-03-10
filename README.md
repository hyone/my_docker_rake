# MyDockerRake

Provide useful rake tasks to build and run a docker project

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'my_docker_rake', github: 'hyone/my_docker_rake'
```

And then execute:

```shell
$ bundle
```

<!---
Or install it yourself as:

```shell
$ gem install my_docker_rake
```
-->

## Usage

Add codes like below to `Rakefile` :

```ruby
require 'my_docker_rake/tasks'

MyDockerRake::Tasks.new do |c|
  c.containers = [
    {
      name:  'mydockerrake.data',
      image: 'mydockerrake/data',
      protect_deletion: true,
    },
    {
      name:  'mydockerrake.sshd',
      image: 'mydockerrake/sshd:v2',
      volumes_from: ['mydockerrake.data'],
      ports: [22]
    },
  ]
end
```

then, provides tasks below :

```sh
rake docker:build[projects,no_cache,build_rm]  # Build project's docker images
rake docker:clean                              # Clean all project's docker images and containers
rake docker:destroy[containers,force_delete]   # Kill and remove project's docker containers
rake docker:kill[containers]                   # Kill project's docker containers
rake docker:push[projects,registry_host]       # Push project's docker images to docker index service
rake docker:restart                            # Destroy and re-run project's containers
rake docker:rm[containers,force_delete]        # Remove project's docker containers
rake docker:rmi[images]                        # Remove project's images
rake docker:run                                # Run project's docker containers
```

## Tasks

### docker:build

Build images from projects under `dockerfiles/` directory.  
*docker:build* treats a sub-directory have `Dockerfile` as a project.

Image name (and also tag if have) is taken from project's (directory) path.  
e.g. `dockerfiles/my_sshd` project is build to image `my/sshd`

- Note that `_` in project name is converted to `/`. ( e.g. `my_sshd` to image name `my/sshd` )

- if we want to add a tag to the image, create sub directories on `image` directory. e.g.
  - `dockerfiles/my_sshd/v1/` project is build to image `my/sshd:v1`
  - `dockerfiles/my_sshd/v2/` project is build to image `my/sshd:v2`

See also a sample project in `spec/sample_project`.

#### task parameters

- `projects` ( `DOCKER_PROJECTS` ) : comma separated project names to build ( e.g. `my_sshd/v2,my_data` )
- `no_cache` ( `DOCKER_NO_CACHE` ) : whether or not use docker build *--no-cache* option
- `build_rm` ( `DOCKER_BUILD_RM` ) : whether or not use docker build *--rm* option

#### configuration

- `after_build` : shell command string to run after build has finished

Example.

```ruby
MyDockerRake::Tasks.new do |c|
  c.after_build = 'docker tag hoge fuga'
end
```

```sh
rake docker:build DOCKER_NO_CACHE=1
```

### docker:run

Run containers with following rules specifed `contaiers` parameter like below:

```ruby
MyDockerRake::Tasks.new do |c|
  c.containers = [
    {
      name:  'mydockerrake.sshd',
      image: 'mydockerrake/sshd:v2',
      ports: [22]
    },
    ...
  ]
end
```

#### configuration

- `containers`: containers settings to run
  - `name`: container name
  - `hostname`: container hostname ( if not specified, use `name` )
  - `links`: container names to link ( e.g. `['hoge_container', 'fuga_container']` )
  - `ports`: ports to expose ( e.g. `[22, 80, '48080:8080']` )
  - `volumes_from`: container names to mount its volumes ( e.g. `['hoge_container', 'fuga_container']` )
  - `options`: to specify other options ( e.g. `'-v /host:/container -w /workdir'` )
  - `protect_deletion`: protect from deletion by `docker:destroy` .  
    useful to set for something like persistent data containers you don't want to delete.

### docker:push

Push project's images to docker registry.  
if `registry_host` parameter is specified, push images to it.  
otherwise push to public docker index registry.

#### task parameters

- `registry_host` ( `DOCKER_REGISTRY_HOST` ) : docker registry host ( e.g. `localhost.localdomain:5000` )

### docker:rm

Remove project containers

#### task parameters

- `containers` ( `DOCKER_CONTAINERS` ) : comma separated container names to delete ( e.g. `hoge_container,fuga_container` )
- `force_delete` ( `DOCKER_FORCE_DELETE` ) : force delete all project's containers ( i.e. also containers set `protect_deletion` )

Example.

```sh
rake docker:rm DOCKER_CONTAINERS=hoge_container,fuga_container DOCKER_FORCE_DELETE=1
```

### docker:destroy

Kill and remove project containers

### docker:clean

Remove all project's images and containers
