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
    rake['docker:rmi'].invoke
  end

  after(:each) do
    rake['docker:rmi'].invoke
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

  let (:image)          { 'mydockerrake/sshd:v2' }
  let (:data_image)     { 'mydockerrake/data' }
  let (:container)      { 'mydockerrake.container' }
  let (:data_container) { 'mydockerrake.container-data' }

  after(:each) {
    rake['docker:destroy:all'].invoke(container, data_container)
  }

  it 'run docker containers' do
    subject.invoke(container, data_container, '', image, data_image)

    has_container?(data_container).should be_true
    running_container?(container).should be_true
  end
end
