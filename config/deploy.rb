set :application, "alchemy-app.com"

set(:user) { Capistrano::CLI.ui.ask("Type in the ssh username: ") }
set(:password) { Capistrano::CLI.password_prompt("Type in the password for #{user}: ") }
set :use_sudo, false
set :scm, :git
set :repository, "git://github.com/tvdeyen/alchemy-app.com.git"
set :port, 12312

set :deploy_via, :remote_cache
set :copy_exclude, [".svn", ".DS_Store"]

role :app, "alchemy-app.com"
role :web, "alchemy-app.com"
role :db,  "alchemy-app.com", :primary => true

set :deploy_to, "/var/www/#{user}/html/webpage"

before "deploy:restart",        "alchemy:assets:copy"
before "deploy:restart",        "deploy:migrate"

after "deploy:setup",           "deploy:db:setup"   unless fetch(:skip_db_setup, false)
after "deploy:setup",           "alchemy:create_shared_folders"
after "deploy:symlink",         "alchemy:symlink_folders"
after "deploy:finalize_update", "deploy:db:symlink"

# Tasks

namespace :deploy do
  
  # We use mod_passenger. If you use i.e. mongrel instances then place your start and stop tasks here.
  
  task :start do ; end
  task :stop do ; end
  
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
  
  # Parts taken from http://gist.github.com/2769
  
  namespace :db do

    desc <<-DESC
      Creates the database.yml configuration file in shared path.

      By default, this task uses a template unless a template \
      called database.yml.erb is found either is :template_dir \
      or /config/deploy folders. The default template matches \
      the template for config/database.yml file shipped with Rails.

      When this recipe is loaded, db:setup is automatically configured \
      to be invoked after deploy:setup. You can skip this task setting \
      the variable :skip_db_setup to true. This is especially useful \ 
      if you are using this recipe in combination with \
      capistrano-ext/multistaging to avoid multiple db:setup calls \ 
      when running deploy:setup for all stages one by one.
    DESC
    task :setup, :except => { :no_release => true } do

      default_template = <<-EOF
      production:
        adapter: mysql
        encoding: utf8
        reconnect: false
        pool: 5
        database: #{ Capistrano::CLI.ui.ask("Database name: ") }
        username: #{ Capistrano::CLI.ui.ask("Database username: ") }
        password: #{ Capistrano::CLI.ui.ask("Database password: ") }
        socket: #{ Capistrano::CLI.ui.ask("Database socket: ") }
      EOF

      location = fetch(:template_dir, "config/deploy") + '/database.yml.erb'
      template = File.file?(location) ? File.read(location) : default_template

      config = ERB.new(template)

      run "mkdir -p #{shared_path}/config" 
      put config.result(binding), "#{shared_path}/config/database.yml"
    end

    desc <<-DESC
      [internal] Updates the symlink for database.yml file to the just deployed release.
    DESC
    task :symlink, :except => { :no_release => true } do
      run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml" 
    end
    
  end
  
end

namespace :alchemy do
  
  namespace :assets do
    task :copy do
      run "cd #{current_path} && RAILS_ENV=production rake alchemy:assets:copy:all"
    end
  end
  
  namespace :db do
    namespace :migrate do

      task :alchemy, :roles => :app, :except => { :no_release => true } do
        run "cd #{current_path} && RAILS_ENV=production rake db:migrate:alchemy"
      end

    end
  end
end
