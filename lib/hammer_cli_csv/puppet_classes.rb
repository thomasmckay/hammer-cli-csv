module HammerCLICsv
  class CsvCommand
    class PuppetClassesCommand < BaseCommand
      command_name 'puppet-classes'
      desc         'import or export puppet classes'

      option %w(--columns), 'COLUMN_NAMES', _('Comma separated list of column names to export')

      SEARCH = 'Search'
      ENVIRONMENTS = 'Environments'
      HOSTGROUPS = 'Host Groups'

      def self.help_columns
        ['', _('Columns:'),
         _(" %{name} - Name of resource") % {:name => NAME},
         _(" %{name} - Search for matching names during import (overrides '%{name_col}' column)") % {:name => SEARCH, :name_col => NAME},
         _(" %{name} - Puppet environments") % {:name => ENVIRONMENTS},
         _(" %{name} - Host groups") % {:name => HOSTGROUPS}
        ].join("\n")
      end

      def column_headers
        @column_values = {}
        if option_columns.nil?
          if ::HammerCLI::Settings.settings[:csv][:columns] &&
              ::HammerCLI::Settings.settings[:csv][:columns]['puppet-classes'.to_sym] &&
              ::HammerCLI::Settings.settings[:csv][:columns]['puppet-classes'.to_sym][:export]
            @columns = ::HammerCLI::Settings.settings[:csv][:columns]['puppet-classes'.to_sym][:export]
          else
            @columns = [NAME, ENVIRONMENTS, HOSTGROUPS]
          end
        else
          @columns = option_columns.split(',')
        end

        if ::HammerCLI::Settings.settings[:csv][:columns] && ::HammerCLI::Settings.settings[:csv][:columns]['puppet-classes'.to_sym] &&
            ::HammerCLI::Settings.settings[:csv][:columns]['puppet-classes'.to_sym][:define]
          @column_definitions = ::HammerCLI::Settings.settings[:csv][:columns]['puppet-classes'.to_sym][:define]
        end

        @columns
      end

      def export(csv)
        csv << column_headers
        iterate_puppet_classes(csv) do |puppet_class|
          predefined_columns(puppet_class)
          custom_columns(puppet_class)
          columns_to_csv(csv)
        end
      end

      def iterate_puppet_classes(csv)
        @api.resource(:organizations).call(:index, {
            'full_results' => true
        })['results'].each do |organization|
          next if option_organization && organization['name'] != option_organization

          total = @api.resource(:puppetclasses).call(:index, {
              'search' => option_search,
              'per_page' => 1
          })['total'].to_i
          (total / 20 + 1).to_i.times do |page|
            @api.resource(:puppetclasses).call(:index, {
                'page' => page + 1,
                'per_page' => 20,
                'search' => option_search
            })['results'].each do |puppet_class|
              puppet_class = @api.resource(:puppetclasses).call(:show, {
                  'id' => puppet_class[1][0]['id']
              })
              yield puppet_class
            end
          end
        end
      end

      def predefined_columns(puppet_class)
        @column_values[NAME] = puppet_class['name']
        @column_values[ENVIRONMENTS] = export_column(puppet_class, 'environments', 'name')
        @column_values[HOSTGROUPS] = export_column(puppet_class, 'hostgroups', 'name')
      end

      def custom_columns(puppet_class)
        return if @column_definitions.nil?
        @column_definitions.each do |definition|
          @column_values[definition[:name]] = dig(puppet_class, definition[:json])
        end
      end

      def dig(puppet_class, path)
        path.inject(puppet_class) do |location, key|
          location.respond_to?(:keys) ? location[key] : nil
        end
      end

      def columns_to_csv(csv)
        if @first_columns_to_csv.nil?
          @columns.each do |column|
            # rubocop:disable LineLength
            if option_export? && !@column_values.key?(column)
              $stderr.puts  _("Warning: Column '%{name}' does not match any field, be sure to check spelling. A full list of supported columns are available with 'hammer csv puppet-classes --help'") % {:name => column}
            end
            # rubocop:enable LineLength
          end
          @first_columns_to_csv = true
        end
        csv << @columns.collect do |column|
          @column_values[column]
        end
      end
    end
  end
end
