# set the applicationname here
set :application, "alchemy-app.com"

set(:user) { Capistrano::CLI.ui.ask("Type in the ssh username: ") }
set(:password) { Capistrano::CLI.password_prompt("Type in the password for #{user}: ") }
set :use_sudo, false
set :scm, :git
set :repository, "git://github.com/tvdeyen/alchemy-app.com.git"
set :port, 12312

set :deploy_via, :remote_cache
set :copy_exclude, [".svn", ".DS_Store"]

# please set domain names
role :app, "alchemy-app.com"
role :web, "alchemy-app.com"
role :db,  "alchemy-app.com", :primary => true

set :deploy_to, "/var/www/#{user}/html/webpage"

before "deploy:restart", "deploy:migrate"

after "deploy:setup", "alchemy:create_shared_folders"
after "deploy:symlink", "alchemy:symlink_folders"
after "deploy:symlink", "alchemy:database_yml"

namespace :alchemy do

  desc "Creates the uploads and pictures cache directory in the shared folder"
  task :create_shared_folders, :roles => :app do
    run "mkdir -p #{shared_path}/uploads/pictures"
    run "mkdir -p #{shared_path}/uploads/attachments"
    run "mkdir -p #{shared_path}/cache/pictures"
  end
  
  desc "Sets the symlinks for uploads and pictures cache folder"
  task :symlink_folders, :roles => :app do
    run "ln -nfs #{shared_path}/uploads #{current_path}/"
    run "ln -nfs #{shared_path}/cache/pictures #{current_path}/public/"
  end
  
  desc "Symlinks the database.yml file"
  task :database_yml, :roles => :app do
    run "ln -nfs #{shared_path}/config/database.yml #{current_path}/config/"
  end
  
  @datestring = Time.now.strftime("%Y_%m_%d_%H_%M_%S")
  
  desc "Get all live data (pictures, attachments and database) from remote server"
  task :get_all_live_data do
    alchemy.get_db_dump
    alchemy.get_pictures
    alchemy.get_attachments
  end
  
  desc "Get all live data (pictures, attachments and database) from remote server and replace the local data with it"
  task :clone_live do
    alchemy.get_all_live_data
    alchemy.import_pictures
    alchemy.import_attachments
    alchemy.import_db
  end
  
  desc "Zip all uploaded pictures and store them in shared/uploads folder on server"
  task :zip_pictures do
    run "cd #{deploy_to}/shared/uploads && tar cfz pictures.tar.gz pictures/"
  end
  
  desc "Zip all uploaded attachments and store them in shared/uploads folder on server"
  task :zip_attachments do
    run "cd #{deploy_to}/shared/uploads && tar cfz attachments.tar.gz attachments/"
  end
  
  desc "Make database dump and store into backup folder"
  task :dump_db do
    db_settings = database_settings['production']
    run "cd #{deploy_to}/shared && mysqldump -u#{db_settings['username']} -p#{db_settings['password']} -S#{db_settings['socket']} -h#{db_settings['host']} #{db_settings['database']} > dump_#{@datestring}.sql"
  end
  
  desc "Get pictures zip from remote server and store it in uploads/pictures.tar.gz"
  task :get_pictures do
    alchemy.zip_pictures
    download "#{deploy_to}/shared/uploads/pictures.tar.gz", "uploads/pictures.tar.gz"
  end
  
  desc "Get attachments zip from remote server and store it in uploads/attachments.tar.gz"
  task :get_attachments do
    alchemy.zip_attachments
    download "#{deploy_to}/shared/uploads/attachments.tar.gz", "uploads/attachments.tar.gz"
  end
  
  desc "Get db dump from remote server and store it in db/<Time>.sql"
  task :get_db_dump do
    alchemy.dump_db
    download "#{deploy_to}/shared/dump_#{@datestring}.sql", "db/dump_#{@datestring}.sql"
  end
  
  desc "Extracts the pictures.tar.gz into the uploads/pictures folder"
  task :import_pictures do
    `rm -rf uploads/pictures`
    `cd uploads/ && tar xzf pictures.tar.gz`
  end
  
  desc "Extracts the attachments.tar.gz into the uploads/attachments folder"
  task :import_attachments do
    `rm -rf uploads/attachments`
    `cd uploads/ && tar xzf attachments.tar.gz`
  end
  
  desc "Imports the database file"
  task :import_db do
    db_settings = database_settings['development']
    `rake db:drop`
    `rake db:create`
    `mysql -uroot #{db_settings['database']} < db/dump_#{@datestring}.sql`
  end
  
end

namespace :deploy do
  desc "Overwrite for the internal Capistrano deploy:start task."
  task :start, :roles => :app do
    run "echo 'Nothing to start'"
  end

  desc "Restart the server"
  task :restart, :roles => :app do
    run "touch #{current_path}/tmp/restart.txt"
  end
end

def database_settings
  if File.exists? "config/database.yml"
    settings = YAML.load_file "config/database.yml"
  else
    raise "Database File not Found!"
  end
  settings
end
