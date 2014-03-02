require 'my_docker_rake/utilities'
require 'rake/tasklib'


module MyDockerRake
  class Tasks < ::Rake::TaskLib
    include MyDockerRake::Utilities

    attr_accessor :image
    attr_accessor :container
    attr_accessor :data_image
    attr_accessor :data_container
    attr_accessor :docker_host
    attr_accessor :no_cache
    attr_accessor :build_options
    attr_accessor :run_options
    attr_accessor :data_run_options

    def docker_host
      @docker_host ||=
        begin
          URI.parse(ENV['DOCKER_HOST'])
        rescue URI::InvalidURIError
          URI.parse('localhost:4243')
        end || 'localhost'
    end


    def initialize(*args, &configure_block)
      configure_block.call(self) if configure_block
      define_tasks
    end

    def define_tasks
      namespace :docker do

        desc 'build docker images'
        task :build, [:projects, :no_cache, :build_options] do |t, args|
          _no_cache      = args.no_cache      || ENV['DOCKER_NO_CACHE']      || no_cache
          _build_options = args.build_options || ENV['DOCKER_BUILD_OPTIONS'] || build_options

          projects = case
            when args.project          then args.projects.split(/,/)
            when ENV['DOCKER_PROJECTS'] then ENV['DOCKER_PROJECTS'].split(/,/)
            else get_projects('./dockerfiles')
            end

          projects.each do |project|
            image = project2image(project)
            puts "---> building #{image} ..."
            sh <<-EOC.gsub(/\s+/, ' ')
              docker build \
                #{_no_cache ? '--no-cache' : ''} \
                -t #{image} \
                #{_build_options} \
                dockerfiles/#{project}
            EOC
          end
        end

        desc 'run the container with persistent data container'
        task :run, [:container, :data_container, :run_options, :image, :data_image] do |t, args|
          _image            = args.image            || ENV['DOCKER_IMAGE']            || image
          _data_image       = args.data_image       || ENV['DOCKER_DATA_IMAGE']       || data_image
          _container        = args.container        || ENV['DOCKER_CONTAINER']        || container
          _data_container   = args.data_container   || ENV['DOCKER_DATA_CONTAINER']   || data_container
          _run_options      = args.run_options      || ENV['DOCKER_RUN_OPTIONS']      || run_options
          _data_run_options = args.data_run_options || ENV['DOCKER_DATA_RUN_OPTIONS'] || data_run_options

          images = [_image, _data_image].reject(&:nil?)
          unless images.all? { |i| has_image?(i) }
            images.each do |i| task('docker:build').invoke(i) end
          end

          # create a data container if doesnt exist
          if _data_container and not has_container?(_data_container)
            sh <<-EOC.gsub(/\s+/, ' ')
              docker run \
                -name #{_data_container} \
                #{_data_run_options} \
                #{_data_image}
            EOC
          end

          unless has_container?(_container)
            sh <<-EOC.gsub(/\s+/, ' ')
              docker run -d \
                -name #{_container} \
                #{_data_container ? "--volumes-from #{_data_container}" : ''} \
                #{_run_options} \
                #{_image}
            EOC
          end
        end

        desc 'push docker image to docker index service'
        task :push, [:project] do |t, args|
          registry_host = "#{docker_host}:5000"

          projects = case
            when args.projects          then args.projects.split(/,/)
            when ENV['DOCKER_PROJECTS'] then ENV['DOCKER_PROJECTS'].split(/,/)
            else get_projects('./dockerfiles')
            end

          projects.each do |project|
            image = project.gsub('_', '/')
            sh "docker tag  #{image} #{registry_host}/#{image}"
            sh "docker push #{registry_host}/#{image}"
          end
        end

        desc 'kill main container'
        task :kill, [:container] do |t, args|
          _container = args.container || ENV['DOCKER_CONTAINER'] || container
          kill_container(_container)
        end

        desc 'remove main container'
        task :rm, [:container] do |t, args|
          _container = args.container || ENV['DOCKER_CONTAINER'] || container
          remove_container(_container)
        end

        desc 'kill and remove main container'
        task :destroy, [:container] do |t, args|
          _container = args.container || ENV['DOCKER_CONTAINER'] || container
          task('docker:kill').invoke(_container)
          task('docker:rm').invoke(_container)
        end

        namespace :destroy do
          desc 'destroy all the containers (include data container)'
          task :all, [:container, :data_container] do |t, args|
            _container = args.container || ENV['DOCKER_CONTAINER'] || container
            task('docker:destroy').invoke(_container)

            _data_container = args.data_container || ENV['DOCKER_DATA_CONTAINER'] || data_container
            remove_container(_data_container)
          end
        end

        desc 'remove project images containers'
        task :rmi, [:images] => ['docker:destroy:all'] do |t, args|
          images = case
            when args.images           then args.projects.split(/,/)
            when ENV['DOCKER_PROJECTS'] then ENV['DOCKER_PROJECTS'].split(/,/)
            else get_projects('./dockerfiles').map { |p| project2image(p) }
            end

          images.each do |image|
            remove_image(image)
          end
        end

        desc "clean project's docker images and containers"
        task :clean => ['docker:rmi']
      end
    end
  end
end
