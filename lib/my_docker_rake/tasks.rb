require 'my_docker_rake/extensions'
require 'my_docker_rake/utilities'
require 'rake/tasklib'


module MyDockerRake
  class Tasks < ::Rake::TaskLib
    include MyDockerRake::Utilities

    class << self
      attr_accessor :application
    end

    attr_accessor :containers
    attr_accessor :no_cache
    attr_accessor :build_rm
    attr_accessor :docker_host

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
      self.class.application = self
    end

    def define_tasks
      namespace :docker do

        desc 'build docker images'
        task :build, [:projects, :no_cache, :build_rm] do |t, args|
          _no_cache = args.no_cache || ENV['DOCKER_NO_CACHE'] || no_cache
          _build_rm = args.build_rm || ENV['DOCKER_BUILD_RM'] || build_rm

          projects = case
            when (not args.projects.blank?) then args.projects.split(/,/)
            when ENV['DOCKER_PROJECTS']     then ENV['DOCKER_PROJECTS'].split(/,/)
            else get_projects('./dockerfiles')
            end

          projects.each do |project|
            image = project2image(project)
            puts "---> building #{image} ..."
            sh <<-EOC.gsub(/\s+/, ' ')
              docker build \
                #{_no_cache ? '--no-cache' : ''} \
                #{_build_rm ? '--rm' : ''} \
                -t #{image} \
                dockerfiles/#{project}
            EOC
          end
        end

        desc 'run project containers'
        task :run do

          images = containers.map { |c| c[:image] }
          unless images.all? { |i| has_image?(i) }
            task('docker:build').invoke
          end

          containers.each do |container|
            if container[:name] and not has_container?(container[:name])
              links = container[:links] || []
              ports = container[:ports] || []
              volumes_from = container[:volumes_from] || []

              sh <<-EOC.gsub(/\s+/, ' ')
                docker run -d \
                  -name #{container[:name]} \
                  #{ links.map { |l| "--link #{l}" }.join(' ') } \
                  #{ ports.map { |p| "-p #{p}" }.join(' ') } \
                  #{ volumes_from.map { |v| "--volumes-from #{v}" }.join(' ') } \
                  #{ container[:options] } \
                  #{ container[:image] }
              EOC
            end
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
        task :kill, [:containers] do |t, args|
          container_names =
            if not args.containers.blank? or ENV['DOCKER_CONTAINERS']
              [(args.containers || ENV['DOCKER_CONTAINERS']).split(/,/)]
            else
              containers.map { |c| c[:name] }
            end

          container_names.each do |c|
            kill_container(c)
          end
        end

        desc 'remove main container'
        task :rm, [:containers, :force_delete] do |t, args|
          _force_delete = args.force_delete || ENV['DOCKER_FORCE_DELETE']

          container_names =
            if not args.containers.blank? or ENV['DOCKER_CONTAINERS']
              [(args.containers || ENV['DOCKER_CONTAINERS']).split(/,/)]
            else
              containers.map { |c| c[:name] }
            end

          unless _force_delete
            containers_hash = containers.inject({}) {|h, c| h[c[:name]] = c; h }
            container_names = container_names.reject { |n| containers_hash[n][:protect_deletion] }
          end

          container_names.each do |container|
            remove_container(container)
          end
        end

        desc 'kill and remove main container'
        task :destroy, [:containers, :force_delete] do |t, args|
          task('docker:kill').invoke(args.containers)
          task('docker:rm').invoke(args.containers, args.force_delete)
        end

        desc 'destroy and re-run the container'
        task :rerun => ['docker:destroy', 'docker:run']

        desc 'remove project images (and containers)'
        task :rmi, [:images] do |t, args|
          images = case
            when args.images            then args.projects.split(/,/)
            when ENV['DOCKER_PROJECTS'] then ENV['DOCKER_PROJECTS'].split(/,/)
            else get_projects('./dockerfiles').map { |p| project2image(p) }
            end

          images.each do |image|
            remove_image(image)
          end
        end

        desc "clean all project's docker images and containers"
        task :clean do
          task('docker:destroy').invoke(nil, true)
          task('docker:rmi').invoke()
        end
      end
    end
  end
end
