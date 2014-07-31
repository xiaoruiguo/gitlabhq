require 'rspec/mocks'

module TestEnv
  extend self

  # Test environment
  #
  # See gitlab.yml.example test section for paths
  #
  def init(opts = {})
    RSpec::Mocks::setup(self)

    # Disable mailer for spinach tests
    disable_mailer if opts[:mailer] == false

    # Setup GitLab shell for test instance
    setup_gitlab_shell

    # Create repository for FactoryGirl.create(:project)
    setup_factory_repo
  end

  def disable_mailer
    NotificationService.any_instance.stub(mailer: double.as_null_object)
  end

  def enable_mailer
    NotificationService.any_instance.unstub(:mailer)
  end

  def setup_gitlab_shell
    unless File.directory?(Gitlab.config.gitlab_shell.path)
      %x[rake gitlab:shell:install]
    end
  end

  def setup_factory_repo
    repo_path = repos_path + "/root/testme.git"
    clone_url = 'https://gitlab.com/gitlab-org/testme.git'

    unless File.directory?(repo_path)
      git_cmd = %W(git clone --bare #{clone_url} #{repo_path})
      puts git_cmd.inspect
      system(*git_cmd)
    end
  end

  def copy_repo(project)
    base_repo_path = repos_path + "/root/testme.git"
    target_repo_path = repos_path + "/#{project.namespace.path}/#{project.path}.git"
    FileUtils.cp_r(base_repo_path, target_repo_path)
  end

  def repos_path
    Gitlab.config.gitlab_shell.repos_path
  end
end
