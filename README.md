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

In `Rakefile` :

```ruby
require 'my_docker_rake/tasks'

MyDockerRake::Tasks.new do |c|
  c.containers = [
    {
      name:  'mydockerrake.sshd',
      image: 'mydockerrake/sshd:v2',
      ports: [22]
    },
    {
      name:  'mydockerrake.data',
      image: 'mydockerrake/data',
      protect_deletion: true,
    }
  ]
end

```

then, provides tasks below:

```sh
rake docker:build[projects,no_cache,build_rm]  # build docker images
rake docker:clean                              # clean all project's docker images and containers
rake docker:destroy[containers,force_delete]   # kill and remove main container
rake docker:kill[containers]                   # kill main container
rake docker:push[project]                      # push docker image to docker index service
rake docker:rerun                              # destroy and re-run the container
rake docker:rm[containers,force_delete]        # remove main container
rake docker:rmi[images]                        # remove project images (and containers)
rake docker:run                                # run project containers
```

## Tasks

### docker:build

Build images from projects under `dockerfiles/`.  
*docker:build* treats sub-directories have `Dockerfile` as projects.

Image name (and also tag if have) is taken from project's (directory) path.  
e.g. `dockerfiles/my_sshd` path is build to image `my/sshd`

- Note that `_` in project name is converted to `/`. ( e.g. `my_sshd` to image name `my/sshd` )

- if we want to add a tag to the image, create sub directories on `image` directory. e.g.
  - `dockerfiles/my_sshd/v1/` project is build to image `my/sshd:v1`
  - `dockerfiles/my_sshd/v2/` project is build to image `my/sshd:v2`

See also a sample project in `spec/sample_project`.

#### task parameters

- `projects` ( `DOCKER_PROJECTS` ): projects to build ( e.g. `my_sshd/v2` )
- `no_cache` ( `DOCKER_NO_CACHE` ): whether or not use docker build *--no-cache* option
- `build_rm` ( `DOCKER_BUILD_RM` ): whether or not use docker build *--rm* option

Example.

```sh
rake docker:build DOCKER_NO_CACHE=1
```

### docker:run

Run containers by following rules specifed `contaiers` like below:

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

#### class configuration

- `containers`: containers settings to run, kill and rm with `docker:run`
  - `links`: container names to link ( e.g. `['hoge_container', 'fuga_container']` )
  - `ports`: ports to expose ( e.g. `[22, 80, '48080:8080']` )
  - `volumes_from`: container names to mount its volumes ( e.g. `['hoge_container', 'fuga_container']` )
  - `options`: to specify other options ( e.g. `'-v /host:/container -w /workdir'` )
  - `protect_deletion`: protect from deletion by `docker:destroy` .  
    useful to set for something like persistent data containers you don't want to delete.

### docker:rm

remove project containers

#### task parameters

- `containers` ( `DOCKER_CONTAINERS` ) : comma separated container names to delete ( e.g. `['hoge_container', 'fuga_container']` )
- `force_delete` ( `DOCKER_FORCE_DELETE` ) : also delete containers set `protect_deletion`

Example.

```sh
rake docker:rm DOCKER_CONTAINERS=hoge_container,fuga_container DOCKER_FORCE_DELETE=1
```

### docker:destroy

kill and remove project containers
