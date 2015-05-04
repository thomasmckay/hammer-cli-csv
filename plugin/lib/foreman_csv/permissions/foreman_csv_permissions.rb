require 'foreman_csv/plugin.rb'

Foreman::Plugin.find(:foreman_csv).security_block :csv do
  permission(:create_content_hosts, {
      'csv/api/v2/content_hosts' => [:upload]
      },
      :resource_type => ::Katello::System
  )
  # permission(:create_content_hosts, {
  #     'csv/api/v2/content_hosts' => [:upload]
  #     },
  #     :resource_type => ::Katello::System
  # )
end
