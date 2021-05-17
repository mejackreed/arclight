# frozen_string_literal: true

require 'rails/generators'

# :nodoc:
class TestAppGenerator < Rails::Generators::Base
  source_root './spec/test_app_templates'

  # if you need to generate any additional configuration
  # into the test app, this generator will be run immediately
  # after setting up the application

  def add_gems
    # gem 'blacklight', '~> 6.0' # Leave commented out until Blacklight 7 drops

    Bundler.with_clean_env do
      run 'bundle install'
    end
  end

  def run_blacklight_generator
    say_status('warning', 'GENERATING BL', :yellow)

    generate 'blacklight:install', '--devise'
  end

  def install_engine
    generate 'arclight:install'
  end

  def add_test_locales
    initializer 'test_locale_configuration.rb' do
      'Blacklight::LocalePicker::Engine.config.available_locales = [:en, :es]'
    end
  end

  def add_custom_download
    config_download = <<~YML
      M0198:
        disabled: false
        ead:
          template: 'http://example.com/%{collection_unitid}.xml'
    YML
    inject_into_file 'config/downloads.yml', config_download, after: "template: 'http://example.com/%{unitid}.xml'\n"
  end
end
