module ForemanCSV
  class Engine < ::Rails::Engine
    isolate_namespace ForemanCSV

    initializer 'foreman_csv.mount_engine', :after => :build_middleware_stack do |app|
      app.routes_reloader.paths << "#{ForemanCSV::Engine.root}/config/mount_engine.rb"
    end

    initializer 'foreman_csv.paths' do |app|
      app.routes_reloader.paths.unshift("#{ForemanCSV::Engine.root}/config/routes/api/foreman_csv.rb")
      app.routes_reloader.paths.unshift("#{ForemanCSV::Engine.root}/config/routes/overrides.rb")
    end

    initializer 'foreman_csv.register_plugin', :after => :finisher_hook do
      require 'foreman_csv/plugin'
      require 'foreman_csv/permissions'
    end

    initializer 'foreman_csv.apipie' do
      Apipie.configuration.api_controllers_matcher << "#{ForemanCSV::Engine.root}" \
        '/app/controllers/foreman_csv/api/v2/*.rb'
      Apipie.configuration.checksum_path += ['/csv/api/']
    end

    initializer 'foreman_csv.register_actions', :before => 'foreman_tasks.initialize_dynflow' do
      ForemanTasks.dynflow.require!
      ForemanTasks.dynflow.config.eager_load_paths.concat(
        ["#{ForemanCSV::Engine.root}/app/lib/foreman_csv/actions"])
    end


    rake_tasks do
      Rake::Task['db:seed'].enhance do
        ForemanCSV::Engine.load_seed
      end
    end
  end
end
