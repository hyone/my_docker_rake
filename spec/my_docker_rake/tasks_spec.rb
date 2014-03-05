require 'spec_helper'


shared_context 'rake' do
  let(:rake)        { Rake::Application.new }
  let(:task_name)   { self.class.top_level_description }
  let(:project_dir) { ::File.expand_path('../../sample_project', __FILE__) }
  let(:projects)    { get_projects(::File.join(project_dir, 'dockerfiles')) }
  subject           { rake[task_name] }

  around(:each) do |example|
    curdir = Dir::getwd
    Dir::chdir(project_dir)

    Rake.application = rake
    Rake.load_rakefile(::File.join(project_dir, 'Rakefile'))
    example.run

    Dir::chdir(curdir)
  end
end


describe 'docker:build' do
  include_context 'rake'

  let (:images) {
    projects.map { |p|
      image, tag = p.split('/')
      image = image.gsub('_', '/')
      [image, tag]
    }
  }

  before(:each) do
    rake['docker:clean'].invoke
  end

  after(:each) do
    rake['docker:clean'].invoke
  end

  it 'build docker images' do
    subject.invoke
    stdout = `docker images`

    images.each do |image, tag|
      stdout.should match /^#{ ::Regexp::escape image }\s+#{ ::Regexp::escape("#{tag}") }/
    end
  end
end


describe 'docker:run' do
  include_context 'rake'

  after(:each) {
    rake['docker:destroy'].invoke()
  }

  it 'run docker containers' do
    subject.invoke()

    MyDockerRake::Tasks.application.containers.each do |c|
      has_container?(c[:name]).should be_true
      # daemon container should keep running
      if c[:ports]
        running_container?(c[:name]).should be_true
      end
    end
  end
end
