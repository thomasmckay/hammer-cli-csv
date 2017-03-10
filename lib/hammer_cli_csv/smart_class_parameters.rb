module HammerCLICsv
  class CsvCommand
    class SmartClassParametersCommand < BaseCommand
      command_name 'smart-class-parameters'
      desc         'import or export smart class parameters'

      option %w(--columns), 'COLUMN_NAMES', _('Comma separated list of column names to export')

      SEARCH = 'Search'
      DESCRIPTION = 'Description'
      PUPPET_CLASS = 'Class'
      PARAMETER_TYPE = 'Parameter Type'
      DEFAULT_VALUE = 'Default Value'
      HIDDEN_VALUE = 'Hidden Value'
      USE_PUPPET_DEFAULT = 'Use Puppet Default'
      REQUIRED = 'Required'
      VALIDATOR_TYPE = 'Validator Type'
      VALIDATOR_RULE = 'Validator Rule'
      MERGE_OVERRIDES = 'Merge Overrides'
      MERGE_DEFAULT = 'Merge Default'
      AVOID_DUPLICATES = 'Avoid Duplicates'
      OVERRIDE = 'Override'
      OVERRIDE_VALUE_ORDER = 'Override Order'
      OVERRIDE_MATCH = 'Override Match'
      OVERRIDE_VALUE = 'Override Value'
      OVERRIDE_OMIT = 'Override Omit'
      OVERRIDE_USE_DEFAULT = 'Override Use Default'

      def self.help_columns
        ['', _('Columns:'),
         _(" %{name} - Name of resource") % {:name => NAME},
         _(" %{name} - Search for matching names during import (overrides '%{name_col}' column)") % {:name => SEARCH, :name_col => NAME},
         #_(" %{name} - Puppet environments") % {:name => ENVIRONMENTS},
         #_(" %{name} - Host groups") % {:name => HOSTGROUPS}
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
            @columns = [NAME, DESCRIPTION, PUPPET_CLASS, PARAMETER_TYPE, DEFAULT_VALUE, HIDDEN_VALUE,
                        USE_PUPPET_DEFAULT, REQUIRED, VALIDATOR_TYPE, VALIDATOR_RULE, MERGE_OVERRIDES,
                        MERGE_DEFAULT, AVOID_DUPLICATES, OVERRIDE, OVERRIDE_VALUE_ORDER,
                        OVERRIDE_MATCH, OVERRIDE_VALUE, OVERRIDE_OMIT, OVERRIDE_USE_DEFAULT]
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
        preset_override_columns = {
          OVERRIDE_MATCH => nil,
          OVERRIDE_VALUE => nil,
          OVERRIDE_OMIT => nil,
          OVERRIDE_USE_DEFAULT => nil
        }
        preset_primary_columns = {
          DESCRIPTION => nil,
          PUPPET_CLASS => nil,
          PARAMETER_TYPE => nil,
          DEFAULT_VALUE => nil,
          HIDDEN_VALUE => nil,
          USE_PUPPET_DEFAULT => nil,
          REQUIRED => nil,
          VALIDATOR_TYPE => nil,
          VALIDATOR_RULE => nil,
          MERGE_OVERRIDES => nil,
          MERGE_DEFAULT => nil,
          AVOID_DUPLICATES => nil,
          OVERRIDE_VALUE_ORDER => nil
        }
        csv << column_headers
        iterate_smart_class_parameters(csv) do |smart_class_parameter|
          predefined_columns(smart_class_parameter)
          custom_columns(smart_class_parameter)
          columns_to_csv(csv, preset_override_columns)

          if smart_class_parameter['override'] == true && smart_class_parameter['override_values_count'] > 0
            preset_primary_columns[OVERRIDE] = 'Remove All'
            columns_to_csv(csv, preset_primary_columns)
            preset_primary_columns[OVERRIDE] = 'Override'
            smart_class_parameter['override_values'].each do |override|
              @column_values[OVERRIDE_MATCH] = override['match']
              @column_values[OVERRIDE_VALUE] = override['value']
              @column_values[OVERRIDE_OMIT] = override['omit'] ? 'Yes' : 'No'
              @column_values[OVERRIDE_USE_DEFAULT] = override['use_puppet_default'] ? 'Yes' : 'No'
              columns_to_csv(csv, preset_primary_columns)
            end
          end
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
              if smart_class_parameter['override_values_count'] > 0
                smart_class_parameter = @api.resource(:smart_class_parameters).call(:show, {
                    'id' => smart_class_parameter['id']
                })
              end
              yield smart_class_parameter
            end
          end
        end
      end

      def predefined_columns(smart_class_parameter)
        @column_values[NAME] = smart_class_parameter['parameter']
        @column_values[DESCRIPTION] = smart_class_parameter['description']
        @column_values[PUPPET_CLASS] = smart_class_parameter['puppet_class']
        @column_values[OVERRIDE] = smart_class_parameter['override'] ? 'Yes' : 'No'
        @column_values[OVERRIDE_VALUE_ORDER] = smart_class_parameter['override_value_order'].split("\n").join(",")
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

      def columns_to_csv(csv, column_value_overrides)
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
          column_value_overrides.key?(column) ? column_value_overrides[column] : @column_values[column]
        end
      end
    end
  end
end
