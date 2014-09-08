require_relative 'extensions'
require_relative 'utilities'
require 'rake/tasklib'


module MyDockerRake
  class Tasks < ::Rake::TaskLib
    include MyDockerRake::Utilities

    class << self
      attr_accessor :application
    end

    attr_accessor :containers
    attr_accessor :no_cache
    attr_accessor :rm_build
    attr_accessor :after_build
    attr_accessor :no_daemon

    def initialize(*args, &configure_block)
      configure_block.call(self) if configure_block
      define_tasks
      self.class.application = self
    end

    def define_tasks
      namespace :docker do

        desc "Build project's docker images"
        task :build, [:projects, :no_cache, :rm_build] do |t, args|
          _no_cache = args.no_cache || ENV['DOCKER_NO_CACHE'] || no_cache
          _rm_build = args.rm_build || ENV['DOCKER_RM_BUILD'] || rm_build

          projects = case
            when !args.projects.blank?
              args.projects.split(/,/)
            when !ENV['DOCKER_PROJECTS'].blank?
              ENV['DOCKER_PROJECTS'].split(/,/)
            else
              get_projects('./dockerfiles')
            end

          projects.each do |project|
            image = project2image(project)
            puts "---> building #{image} ..."
            sh <<-EOC.gsub(/\s+/, ' ')
              docker build \
                #{_no_cache ? '--no-cache' : ''} \
                #{_rm_build ? '--rm' : ''} \
                -t #{image} \
                dockerfiles/#{project}
            EOC
          end

          unless after_build.blank?
            sh after_build
          end
        end

        desc "Run project's docker containers"
        task :run, [:container, :no_daemon] do |t, args|
          _no_daemon = args.no_daemon || ENV['DOCKER_NO_DAEMON'] || no_daemon

          container_names =
            if not args.container.blank? or ENV['DOCKER_CONTAINER']
              [args.container || ENV['DOCKER_CONTAINER']]
            else
              containers.map { |c| c[:name] }
            end

          images = containers
                     .select { |c| container_names.member?(c[:name]) and c[:image] }
                     .map { |c| c[:image] }
          unless images.all? { |i| has_image?(i) }
            task('docker:build').invoke
          end

          containers.each do |container|
            if container[:name].blank? or
              not container_names.member?(container[:name]) or
              # if the container already exists
              has_container?(container[:name])
                next
            end

            links = container[:links] || []
            ports = container[:ports] || []
            volumes_from = container[:volumes_from] || []

            sh <<-EOC.gsub(/\s+/, ' ')
              docker run \
                #{ _no_daemon ? '' : '-d' } \
                --name #{container[:name]} \
                --hostname #{container[:hostname] || container[:name].gsub(/\./, '_')} \
                #{ links.map { |l| "--link #{l}" }.join(' ') } \
                #{ ports.map { |p| "-p #{p}" }.join(' ') } \
                #{ volumes_from.map { |v| "--volumes-from #{v}" }.join(' ') } \
                #{ container[:options] } \
                #{ container[:image] }
            EOC
          end
        end

        desc "synonym of task 'docker:run'"
        task :create => ['docker:run']

        desc "start containers"
        task :start do
          containers.each do |container|
            if container[:name] and has_container?(container[:name])
              sh <<-EOC.gsub(/\s+/, ' ')
                docker start #{container[:name]}
              EOC
            end
          end
        end

        desc "stop containers"
        task :stop do
          containers.each do |container|
            if container[:name] and has_container?(container[:name])
              sh <<-EOC.gsub(/\s+/, ' ')
                docker stop #{container[:name]}
              EOC
            end
          end
        end

        desc "Push project's docker images to docker index service"
        task :push, [:projects, :registry_host, :rm_images] do |t, args|
          registry_host = args.registry_host || ENV['DOCKER_REGISTRY_HOST']
          rm_images     = args.rm_images     || ENV['DOCKER_RM_IMAGES'] || false

          projects = case
            when !args.projects.blank?
              args.projects.split(/,/)
            when !ENV['DOCKER_PROJECTS'].blank?
              ENV['DOCKER_PROJECTS'].split(/,/)
            else
              get_projects('./dockerfiles')
            end

          images = projects.map { |p| project2image(p) }
          repos  = images.map { |i| i.split(':').shift }.uniq
          prefix = registry_host.blank? ? '' : "#{registry_host}/"

          deploy_images = images.map do |image|
            fullname = "#{prefix}#{image}"
            [image, fullname]
          end

          # if the image do not have a tag,
          # we additionally tags current date to identify the current image build
          version = Time.now.strftime('%Y%m%d%H%M')

          deploy_images += images.map { |image|
            name, tag = image.split(':')
            tag = tag.blank? ? version : "#{tag}+#{version}"
            fullname = "#{prefix}#{name}:#{tag}"
            [image, fullname]
          }

          # tagging
          deploy_images.each do |image, fullname|
            sh "docker tag #{image} #{fullname}"
          end

          # push
          repos.each do |repo|
            # private docker registry
            if registry_host
              sh "docker push #{registry_host}/#{repo}"
            # public
            else
              sh "docker push #{repo}"
            end
          end

          if rm_images
            deploy_images.each do |_, fullname|
              remove_image(fullname)
            end
          end
        end

        desc "Kill project's docker containers"
        task :kill, [:container] do |t, args|
          container_names =
            if not args.container.blank? or ENV['DOCKER_CONTAINER']
              [args.container || ENV['DOCKER_CONTAINER']]
            else
              containers.map { |c| c[:name] }
            end

          container_names.each do |c|
            kill_container(c)
          end
        end

        desc "Remove project's docker containers"
        task :rm, [:containers, :force_delete] do |t, args|
          _force_delete = args.force_delete || ENV['DOCKER_FORCE_DELETE']

          container_names =
            if not args.container.blank? or ENV['DOCKER_CONTAINER']
              [args.container || ENV['DOCKER_CONTAINER']]
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

        desc "Kill and remove project's docker containers"
        task :destroy, [:containers, :force_delete] do |t, args|
          task('docker:kill').invoke(args.containers)
          task('docker:rm').invoke(args.containers, args.force_delete)
        end

        desc "Destroy and re-run project's containers"
        task :recreate => ['docker:destroy', 'docker:run']

        desc "synonym of task 'docker:recreate'"
        task :rerun => ['docker:recreate']

        desc "restart containers"
        task :restart do
          containers.each do |container|
            if container[:name] and has_container?(container[:name])
              sh <<-EOC.gsub(/\s+/, ' ')
                docker restart #{container[:name]}
              EOC
            end
          end
        end

        desc "Remove project's images"
        task :rmi, [:images] do |t, args|
          images = case
            when !args.images.blank?
              args.projects.split(/,/)
            when !ENV['DOCKER_PROJECTS'].blank?
              ENV['DOCKER_PROJECTS'].split(/,/).map { |p| project2image(p) }
            else
              get_projects('./dockerfiles').map { |p| project2image(p) }
            end

          images.each do |image|
            remove_image(image)
          end
        end

        desc "Clean all project's docker images and containers"
        task :clean do
          task('docker:destroy').invoke(nil, true)
          task('docker:rmi').invoke()
        end
      end
    end
  end
end
