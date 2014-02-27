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

Or install it yourself as:

```shell
$ gem install my_docker_rake
```

## Usage

In `Rakefile` :

```ruby
require 'my_docker_rake/tasks'

MyDockerRake::Tasks.new do |c|
  c.image = 'mydockerrake/sshd'
  c.container = 'mydockerrake.sshd'
  c.data_image = 'mydockerrake/data'
  c.data_container = 'mydockerrake.data'
end
```

then, provides tasks below:

```sh
rake docker:build[project,no_cache]                               # build docker images
rake docker:clean                                                 # clean all docker containers and non named images
rake docker:destroy[container]                                    # kill and remove main container
rake docker:destroy:all[container,data_container]                 # destroy all the containers (include data cont...
rake docker:kill[container]                                       # kill main container
rake docker:push[project]                                         # push docker image to docker index service
rake docker:rm[container]                                         # remove main container
rake docker:rmi[images]                                           # remove project images
rake docker:run[container,data_container,ports,image,data_image]  # run the container with persistent data containe
```

## Tasks

### docker:build

Build images from projects under `dockerfiles/`.  
*docker:build* treats sub-directories have `Dockerfile` as projects.

Image name (and also tag if have) is taken from project's (directory) name.  

- Note that `_` in project name is converted to `/`. ( e.g. `my_sshd` to image name `my/sshd` )

- if we want to add a tag to the image, create sub directories on `image` directory. e.g.
  - `dockerfiles/my_sshd/v1/` project is build to image `my/sshd:v1`
  - `dockerfiles/my_sshd/v2/` project is build to image `my/sshd:v2`
  - `dockerfiles/my_hoge/` project is build to image `my/hoge`

See also a sample project in `spec/sample_project`.

### docker:run

Run container ( if set `docker_data_image`, with creating and mounting persistent data container )
image and container can specify parameters below:

- `image` : image name of container to run
- `data_image` : image name of persistent data container
- `container` : container name to run
- `data_container` : persistent data container name
- `ports` : port options of *docker run* command ( e.g. `'-p 48080:8080 -p ...'` )
