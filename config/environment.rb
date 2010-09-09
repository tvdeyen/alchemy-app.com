RAILS_GEM_VERSION = '2.3.8' unless defined? RAILS_GEM_VERSION

require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  config.gem 'acts_as_ferret', :version => '0.4.8'
  config.gem 'authlogic', :version => '>=2.1.2'
  config.gem 'awesome_nested_set', :version => '>=1.4.3'
  config.gem 'declarative_authorization', :version => '>=0.4.1'
  config.gem "fleximage", :version => ">=1.0.1"
  config.gem 'fast_gettext', :version => '>=0.4.8'
  config.gem 'gettext_i18n_rails', :version => '>=0.2.3'
  config.gem 'gettext', :lib => false, :version => '>=1.9.3'
  config.gem 'rmagick', :lib => "RMagick2", :version => '>=2.12.2'
  config.gem 'tvdeyen-ferret', :version => '>=0.11.8.1', :lib => 'ferret'
  config.gem 'will_paginate', :version => '>=2.3.12'
  config.gem 'mimetype-fu', :version => '>=0.1.2', :lib => 'mimetype_fu'
  
  config.load_paths += %W( vendor/plugins/alchemy/app/sweepers )
  config.load_paths += %W( vendor/plugins/alchemy/app/middleware )
  
  config.i18n.load_path += Dir[Rails.root.join('vendor/plugins/alchemy/config', 'locales', '*.{rb,yml}')]
  config.i18n.default_locale = :de
  config.active_record.default_timezone = :berlin
end
