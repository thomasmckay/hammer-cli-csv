module HammerCLICsv
  class CsvCommand
    class Satellite5Command < HammerCLI::Apipie::Command
      command_name 'satellite-5'
      desc         'convert a Satellite-5 export to CSV'

      option %w(-v --verbose), :flag, _('be verbose')
      option '--input-dir', 'INPUT_DIRECTORY', _('directory to import from')
      option '--output-dir', 'OUTPUT_DIRECTORY', _('directory to export to')

      def execute
        @server = (HammerCLI::Settings.settings[:_params] &&
                   HammerCLI::Settings.settings[:_params][:host]) ||
          HammerCLI::Settings.get(:csv, :host) ||
          HammerCLI::Settings.get(:katello, :host) ||
          HammerCLI::Settings.get(:foreman, :host)
        @username = (HammerCLI::Settings.settings[:_params] &&
                     HammerCLI::Settings.settings[:_params][:username]) ||
          HammerCLI::Settings.get(:csv, :username) ||
          HammerCLI::Settings.get(:katello, :username) ||
          HammerCLI::Settings.get(:foreman, :username)
        @password = (HammerCLI::Settings.settings[:_params] &&
                     HammerCLI::Settings.settings[:_params][:password]) ||
          HammerCLI::Settings.get(:csv, :password) ||
          HammerCLI::Settings.get(:katello, :password) ||
          HammerCLI::Settings.get(:foreman, :password)

        @api = ApipieBindings::API.new({
                                         :uri => @server,
                                         :username => @username,
                                         :password => @password,
                                         :api_version => 2
                                       })

        process_input_files

        HammerCLI::EX_OK
      end

      def process_input_files
        process_users
        process_repositories
      end

      NAME = 'Name'

      # users.rb
      FIRSTNAME = 'First Name'
      LASTNAME = 'Last Name'
      EMAIL = 'Email'
      ORGANIZATIONS = 'Organizations'
      LOCATIONS = 'Locations'
      ADMIN = 'Administrator'
      ROLES = 'Roles'

      # organizations.rb
      LABEL = 'Label'
      DESCRIPTION = 'Description'

      # roles.rb
      RESOURCE = 'Resource'
      SEARCH = 'Search'
      PERMISSIONS = 'Permissions'
      #ORGANIZATIONS = 'Organizations'
      #LOCATIONS = 'Locations'

      # TODO: copied from base.rb
      def labelize(name)
        name.gsub(/[^a-z0-9\-_]/i, '_')
      end

      def collect_column(column)
        return [] if column.nil? || column.empty?
        CSV.parse_line(column, {:skip_blanks => true}).collect do |value|
          yield value
        end
      end

      def process_users
        input_file = "#{option_input_dir}/users.csv"
        output_users_file = "#{option_output_dir}/users.csv"
        output_organizations_file = "#{option_output_dir}/organizations.csv"
        output_roles_file = "#{option_output_dir}/roles.csv"
        raise "File '%{input_file}' does not exist" % (input_file) unless File.exist? input_file

        @existing_organizations = {}
        @existing_roles = {}

        CSV.open(input_file, {
                   :skip_blanks => true,
                   :headers => :first_row,
                   :return_headers => false
                 }).each do |line|
          CSV.open(output_users_file, 'wb', {:force_quotes => true}) do |csv_users|
            CSV.open(output_organizations_file, 'wb', {:force_quotes => true}) do |csv_organizations|
              CSV.open(output_roles_file, 'wb', {:force_quotes => true}) do |csv_roles|
                csv_users << [NAME, FIRSTNAME, LASTNAME, EMAIL, ORGANIZATIONS, LOCATIONS, ADMIN, ROLES]
                csv_organizations << [NAME, LABEL, DESCRIPTION]
                csv_roles << [NAME, RESOURCE, SEARCH, PERMISSIONS, ORGANIZATIONS, LOCATIONS]

                unless @existing_organizations[line['organization_id']]
                  @existing_organizations[line['organization_id']] = line['organization']
                  csv_organizations << [line['organization'], labelize(line['organization'])]
                end

                roles = []
                CSV.parse_line(line['role'], { :col_sep => ';', :skip_blanks => true }).collect do |role|
                  unless @existing_roles[role]
                    @existing_roles[role] = role
                    csv_roles << [role, '', '', '', line['organization'], '']
                  end
                  roles << role
                end
                roles = CSV.generate do |column|
                  column << roles
                end
                roles.delete!("\n")

                if line['active'] == 'enabled'
                  csv_users << [line['username'], line['first_name'], line['last_name'],
                                line['email'], line['organization'], '', true, roles]
                end
              end
            end
          end
        end
      end

      #LABEL = 'Label'
      #ORGANIZATION = 'Organization'
      REPOSITORY = 'Repository'
      REPOSITORY_TYPE = 'Repository Type'
      REPOSITORY_URL = 'Repository Url'
      #DESCRIPTION = 'Description'

      def process_repositories

        input_file = "#{option_input_dir}/repositories.csv"
        output_products_file = "#{option_output_dir}/products.csv"
        raise "File '%{input_file}' does not exist" % (input_file) unless File.exist? input_file

        @existing_organizations = {}
        @existing_roles = {}

        CSV.open(input_file, {
                   :skip_blanks => true,
                   :headers => :first_row,
                   :return_headers => false
                 }).each do |line|
          CSV.open(output_products_file, 'wb', {:force_quotes => true}) do |csv_products|
            csv_products << [NAME, LABEL, ORGANIZATION, DESCRIPTION, REPOSITORY, REPOSITORY_TYPE,
                             REPOSITORY_URL]
          end
        end
      end
    end
  end
end
