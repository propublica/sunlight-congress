# set :environment, (ENV['target'] || 'staging')

set :user, 'rtc'
set :application, user
set :deploy_to, "/projects/#{user}/"

# if environment == 'production'
#   set :domain, 'realtimecongress.org'
# else # environment == 'staging'
  set :domain, 'rtc.sunlightlabs.com'
# end

set :scm, :git
set :repository, "git://github.com/sunlightlabs/realtimecongress.git"
set :branch, 'master'

set :deploy_via, :remote_cache
set :runner, user
set :admin_runner, runner

role :app, domain
role :web, domain

set :use_sudo, false
after "deploy", "deploy:cleanup"
after "deploy:update_code", "deploy:shared_links"


namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :migrate do; end
  
  desc "Restart the server"
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join current_path, 'tmp', 'restart.txt'}"
  end
  
  desc "Get shared files into position"
  task :shared_links, :roles => [:web, :app] do
    run "ln -nfs #{shared_path}/config.yml #{release_path}/config/config.yml"
    run "ln -nfs #{shared_path}/config.ru #{release_path}/config.ru"
    run "ln -nfs #{shared_path}/data #{release_path}/data"
    run "rm #{File.join release_path, 'tmp', 'pids'}"
    run "rm #{File.join release_path, 'public', 'system'}"
    run "rm #{File.join release_path, 'log'}"
  end
end