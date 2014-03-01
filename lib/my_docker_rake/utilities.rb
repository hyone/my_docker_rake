require 'rake/file_utils_ext'
require 'find'
require 'pathname'


module MyDockerRake
  module Utilities
    extend self

    def running_container?(container)
      `docker inspect -format "{{ .State.Running }}" #{container} 2>/dev/null`.chomp == 'true'
    end

    def has_container?(container)
      system("docker inspect #{container} >/dev/null 2>&1")
    end

    def kill_container(container, *args)
      if running_container?(container)
        sh(<<-EOC, *args)
          docker kill #{container}
        EOC
      end
    end

    def remove_container(container, *args)
      if has_container?(container)
        sh(<<-EOC, *args)
          docker rm #{container}
        EOC
      end
    end

    def destroy_container(*args)
      kill_container(*args)
      remove_container(*args)
    end

    def has_image?(image)
      return false if "#{image}".empty?

      name, tag = image.split(':')
      system <<-EOC
        docker images #{name} | grep -E '^#{Regexp::escape name}\s+#{Regexp::escape "#{tag}"}' \
          >/dev/null
      EOC
    end

    def remove_image(image, *args)
      if has_image?(image)
        sh(<<-EOC, *args)
          docker rmi #{image}
        EOC
      end
    end

    def get_projects(dir)
      Find.find(dir).select { |fpath|
        File.directory?(fpath) and File.exists?(File.join(fpath, 'Dockerfile'))
      }.map { |fpath|
        Pathname.new(fpath).relative_path_from(Pathname.new(dir)).to_s
      }
    end

    def project2image(project)
      image, tag = project.split('/')
      image = image.gsub('_', '/')

      "#{image}#{tag ? ":#{tag}" : ''}"
    end

    def sh(cmd, options = {})
      cmd = cmd.sub(/^\s+(.*?)\s+$/, '\1')
      # throw away outputs when set false explicitly
      Rake::FileUtilsExt.sh(
        "#{cmd} #{options[:verbose] == false ? '>/dev/null 2>&1' : ''}",
        options
      )
    end
    private :sh

  end
end
