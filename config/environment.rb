RAILS_GEM_VERSION = '2.3.8' unless defined? RAILS_GEM_VERSION

require File.join(File.dirname(__FILE__), 'boot')
require File.join(File.dirname(__FILE__), '../vendor/plugins/alchemy/plugins/engines/boot')

Rails::Initializer.run do |config|
  config.gem 'ferret'
  config.gem "grosser-fast_gettext", :version => '>=0.4.8', :lib => 'fast_gettext', :source => "http://gems.github.com"
  config.gem "gettext", :lib => false, :version => '>=1.9.3'
  config.gem "rmagick", :lib => "RMagick2"
  config.gem 'mime-types', :lib => "mime/types"
  
  config.plugin_paths << File.join(File.dirname(__FILE__), '../vendor/plugins/alchemy/plugins')
  config.plugin_paths << File.join(File.dirname(__FILE__), '../vendor/plugins/mailings/plugins')
  config.plugins = [ :declarative_authorization, :alchemy, :all ]
  config.load_paths += %W( #{RAILS_ROOT}/vendor/plugins/alchemy/app/sweepers )
  config.load_paths += %W( #{RAILS_ROOT}/vendor/plugins/alchemy/app/middleware )
  config.i18n.load_path += Dir[Rails.root.join('vendor/plugins/alchemy/config', 'locales', '*.{rb,yml}')]
  config.i18n.default_locale = :de
  config.active_record.default_timezone = :berlin
  config.action_controller.session = { :key => "_alchemy_session", :secret => "2f1eb8a264b7dd21a1d459c744afe27154b5544e15f861d23078301b8895e194b601103797db880f0de15d73fe5d196e8c372b9b0f5b81b786e0d906633a9fc2" }
end
