module HammerCLICsv
  class CsvCommand
    class SmartClassParametersCommand < BaseCommand
      command_name 'smart-class-parameters'
      desc         'import or export smart class parameters'

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
              ::HammerCLI::Settings.settings[:csv][:columns]['smart-class-parameters'.to_sym] &&
              ::HammerCLI::Settings.settings[:csv][:columns]['smart-class-parameters'.to_sym][:export]
            @columns = ::HammerCLI::Settings.settings[:csv][:columns]['smart-class-parameters'.to_sym][:export]
          else
            @columns = [NAME, ENVIRONMENTS, HOSTGROUPS]
          end
        else
          @columns = option_columns.split(',')
        end

        if ::HammerCLI::Settings.settings[:csv][:columns] && ::HammerCLI::Settings.settings[:csv][:columns]['smart-class-parameters'.to_sym] &&
            ::HammerCLI::Settings.settings[:csv][:columns]['smart-class-parameters'.to_sym][:define]
          @column_definitions = ::HammerCLI::Settings.settings[:csv][:columns]['smart-class-parameters'.to_sym][:define]
        end

        @columns
      end

      def export(csv)
        csv << column_headers
        iterate_smart_class_parameters(csv) do |smart_class_parameter|
          predefined_columns(smart_class_parameter)
          custom_columns(smart_class_parameter)
          columns_to_csv(csv)
        end
      end

      def iterate_smart_class_parameters(csv)
        @api.resource(:organizations).call(:index, {
            'full_results' => true
        })['results'].each do |organization|
          next if option_organization && organization['name'] != option_organization

          total = @api.resource(:smart_class_parameters).call(:index, {
              'search' => option_search,
              'per_page' => 1
          })['total'].to_i
          (total / 20 + 1).to_i.times do |page|
            @api.resource(:smart_class_parameters).call(:index, {
                'page' => page + 1,
                'per_page' => 20,
                'search' => option_search
            })['results'].each do |smart_class_parameter|
              smart_class_parameter = @api.resource(:smart_class_parameters).call(:show, {
                  'id' => smart_class_parameter[1][0]['id']
              })
              yield smart_class_parameter
            end
          end
        end
      end

      def predefined_columns(smart_class_parameter)
        @column_values[NAME] = smart_class_parameter['name']
        @column_values[ENVIRONMENTS] = export_column(smart_class_parameter, 'environments', 'name')
        @column_values[HOSTGROUPS] = export_column(smart_class_parameter, 'hostgroups', 'name')
      end

      def custom_columns(smart_class_parameter)
        return if @column_definitions.nil?
        @column_definitions.each do |definition|
          @column_values[definition[:name]] = dig(smart_class_parameter, definition[:json])
        end
      end

      def dig(smart_class_parameter, path)
        path.inject(smart_class_parameter) do |location, key|
          location.respond_to?(:keys) ? location[key] : nil
        end
      end

      def columns_to_csv(csv)
        if @first_columns_to_csv.nil?
          @columns.each do |column|
            # rubocop:disable LineLength
            if option_export? && !@column_values.key?(column)
              $stderr.puts  _("Warning: Column '%{name}' does not match any field, be sure to check spelling. A full list of supported columns are available with 'hammer csv smart-class-parameters --help'") % {:name => column}
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
