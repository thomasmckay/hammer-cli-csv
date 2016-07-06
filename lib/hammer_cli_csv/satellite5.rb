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
      # TODO: end

      def process_users
        input_file = "#{option_input_dir}/users.csv"
        output_users_file = "#{option_output_dir}/users.csv"
        output_organizations_file = "#{option_output_dir}/organizations.csv"
        output_roles_file = "#{option_output_dir}/roles.csv"
        raise _("File '%{input_file}' does not exist") % {input_file => input_file} unless File.exist? input_file

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
                csv_users << [UsersCommand::NAME, UsersCommand::FIRSTNAME, UsersCommand::LASTNAME,
                              UsersCommand::EMAIL, UsersCommand::ORGANIZATIONS,
                              UsersCommand::LOCATIONS, UsersCommand::ADMIN, UsersCommand::ROLES]
                csv_organizations << [OrganizationsCommand::NAME, OrganizationsCommand::LABEL,
                                      OrganizationsCommand::DESCRIPTION]
                csv_roles << [RolesCommand::NAME, RolesCommand::RESOURCE, RolesCommand::SEARCH,
                              RolesCommand::PERMISSIONS, RolesCommand::ORGANIZATIONS,
                              RolesCommand::LOCATIONS]

                unless @existing_organizations[line['organization_id']]
                  @existing_organizations[line['organization_id']] = line['organization']
                  csv_organizations << [line['organization'], labelize(line['organization']), '']
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

      def process_repositories

        input_repositories_file = "#{option_input_dir}/repositories.csv"
        output_products_file = "#{option_output_dir}/products.csv"
        raise _("File '%{input_file}' does not exist") % {input_file => input_repositories_file} unless File.exist? input_repositories_file
        input_channels_file = "#{option_input_dir}/channels.csv"
        raise _("File '%{input_file}' does not exist") % {input_file => input_channels_file} unless File.exist? input_channels_file

        CSV.open(output_products_file, 'wb', {:force_quotes => true}) do |csv_products|
          csv_products << [ProductsCommand::NAME, ProductsCommand::LABEL,
                           ProductsCommand::ORGANIZATION, ProductsCommand::DESCRIPTION,
                           ProductsCommand::REPOSITORY, ProductsCommand::REPOSITORY_TYPE,
                           ProductsCommand::REPOSITORY_URL]
          CSV.open(input_repositories_file, {
                     :skip_blanks => true,
                     :headers => :first_row,
                     :return_headers => false
                   }).each do |line|
            name = line['repo_label']
            label = labelize(line['repo_label'])
            organization = @existing_organizations[line['org_id']]
            description = ''
            repository = name
            repository_url = line['source_url']
            repository_type = 'Custom Yum'  # TODO: line['repo_type']
            # TODO: client_key_descr,client_key_type,client_key,client_cert_descr,client_cert_type,client_cert,ca_descr,ca_type,ca_key
            csv_products << [name, label, organization, description, repository,
                             repository_type, repository_url]
          end
          CSV.open(input_channels_file, {
                     :skip_blanks => true,
                     :headers => :first_row,
                     :return_headers => false
                   }).each do |line|
            name = line['channel_name']
            label = labelize(line['channel_label'])
            organization = @existing_organizations[line['org_id']]
            description = ''
            repository = name
            repository_url = "file://#{option_input_dir}/CHANNELS/#{line['org_id']}/#{line['channel_id']}"
            repository_type = 'Custom Yum'  # TODO: line['repo_type']
            # TODO: client_key_descr,client_key_type,client_key,client_cert_descr,client_cert_type,client_cert,ca_descr,ca_type,ca_key
            csv_products << [name, label, organization, description, repository,
                             repository_type, repository_url]
          end
        end
      end
    end
  end
end
