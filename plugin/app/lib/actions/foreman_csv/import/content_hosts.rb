#
# Copyright 2015 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

module Actions
  module ForemanCSV
    module Import
      class ContentHosts < ImportAction
        middleware.use ::Actions::Middleware::KeepCurrentUser
        middleware.use ::Actions::Middleware::KeepLocale

        def plan(file_name)
          plan_self(:file_name => file_name)
        end

        def run
          @hypervisor_guests = {}

          thread_import(input[:file_name]) do |line|
            create_content_hosts_from_csv(line)
          end

          if !@hypervisor_guests.empty?
            print(_('Updating hypervisor and guest associations...')) if option_verbose?
            @hypervisor_guests.each do |host_id, guest_ids|
              host = ::Katello::System.find(host_id)
              ::ForemanTasks.sync_task(::Actions::Katello::System::Update, host, {
                  'guestIds' => guest_ids
              })
            end
            puts _('done') if option_verbose?
          end
        end

        private

        ORGANIZATION = 'Organization'
        ENVIRONMENT = 'Environment'
        CONTENTVIEW = 'Content View'
        HOSTCOLLECTIONS = 'Host Collections'
        VIRTUAL = 'Virtual'
        HOST = 'Host'
        OPERATINGSYSTEM = 'OS'
        ARCHITECTURE = 'Arch'
        SOCKETS = 'Sockets'
        RAM = 'RAM'
        CORES = 'Cores'
        SLA = 'SLA'
        PRODUCTS = 'Products'
        SUBSCRIPTIONS = 'Subscriptions'

        def option_organization
          nil # TODO: input[:organization]
        end

        def option_verbose?
          true # TODO: needed?
        end

        def create_content_hosts_from_csv(line)
          return if option_organization && line[ORGANIZATION] != option_organization
          ::User.current = ::User.find(input[:current_user_id])
          organization = Organization.find_by_name(line[ORGANIZATION])
          environment = ::Katello::KTEnvironment.where(:name => line[ENVIRONMENT], :organization_id => organization.id).first
          content_view = ::Katello::ContentView.where(:name => line[CONTENTVIEW], :organization_id => organization.id).first
          installed_products = products(line)

          line[COUNT].to_i.times do |number|
            name = namify(line[NAME], number)

            content_host = ::Katello::System.in_organization(organization).find_by_name(name)
            if content_host.nil?
              print(_("Creating content host '%{name}'...") % {:name => name}) if option_verbose?
              content_host = ::Katello::System.new({
                  'name' => name,
                  'environment' => environment,
                  'content_view' => content_view,
                  'facts' => facts(name, line),
                  'installedProducts' => installed_products,
                  'serviceLevel' => line[SLA],
                  'cp_type' => 'system'
              })
              ::ForemanTasks.sync_task(::Actions::Katello::System::Create, content_host)
              content_host.reload
            else
              print(_("Updating content host '%{name}'...") % {:name => name}) if option_verbose?
              ::ForemanTasks.sync_task(::Actions::Katello::System::Update, content_host, {
                  'name' => name,
                  'environment_id' => environment.id,
                  'content_view_id' => content_view.id,
                  'facts' => facts(name, line),
                  'installedProducts' => installed_products,
                  'serviceLevel' => line[SLA]
              })
            end

            if line[VIRTUAL] == 'Yes' && line[HOST]
              hypervisor = ::Katello::System.in_organization(organization).find_by_name(line[HOST])
              raise "Content host '#{line[HOST]}' not found" if !hypervisor
              @hypervisor_guests[hypervisor.id] ||= []
              @hypervisor_guests[hypervisor.id] << "#{line[ORGANIZATION]}/#{name}"
            end

            update_host_collections(content_host, line)
            update_subscriptions(content_host, line)

            puts _('done') if option_verbose?
          end
        rescue RuntimeError => e
          raise "#{e}\n       #{line}"
        end

        def facts(name, line)
          facts = {}
          facts['system.certificate_version'] = '3.2'  # Required for auto-attach to work
          facts['network.hostname'] = name
          facts['cpu.core(s)_per_socket'] = line[CORES] unless line[CORES].empty?
          facts['cpu.cpu_socket(s)'] = line[SOCKETS] unless line[SOCKETS].empty?
          facts['memory.memtotal'] = line[RAM] unless line[RAM].empty?
          facts['uname.machine'] = line[ARCHITECTURE] unless line[ARCHITECTURE].empty?
          (facts['distribution.name'], facts['distribution.version']) = os_name_version(line[OPERATINGSYSTEM]) unless line[OPERATINGSYSTEM].empty?
          facts['virt.is_guest'] = line[VIRTUAL] == 'Yes' ? true : false
          facts['virt.uuid'] = "#{line[ORGANIZATION]}/#{name}" if facts['virt.is_guest']
          facts['cpu.cpu(s)'] = 1
          facts
        end

        def update_host_collections(content_host, line)
          return nil if !line[HOSTCOLLECTIONS]
          CSV.parse_line(line[HOSTCOLLECTIONS]).each do |hostcollection_name|
            host_collection = ::Katello::HostCollection.find_by_name(hostcollection_name)
            host_collection.system_ids << content_host.id
            host_collection.save!
          end
        end

        def os_name_version(operatingsystem)
          if operatingsystem.nil?
            name = nil
            version = nil
          elsif operatingsystem.index(' ')
            (name, version) = operatingsystem.split(' ')
          else
            (name, version) = ['RHEL', operatingsystem]
          end
          [name, version]
        end

        def products(line)
          return nil if !line[PRODUCTS]
          products = CSV.parse_line(line[PRODUCTS]).collect do |product_details|
            product = {}
            (product['productId'], product['productName']) = product_details.split('|')
            product['arch'] = line[ARCHITECTURE]
            product['version'] = os_name_version(line[OPERATINGSYSTEM])[1]
            product
          end
          products
        end

        def update_subscriptions(content_host, line)
          content_host.unsubscribe_all

          return if line[SUBSCRIPTIONS].empty?
          organization = Organization.find_by_name(line[ORGANIZATION])

          subscriptions = CSV.parse_line(line[SUBSCRIPTIONS], {:skip_blanks => true}).collect do |details|
            (amount, sku, name) = details.split('|')
            quantity = (amount.nil? || amount.empty? || amount == 'Automatic') ? 0 : amount.to_i

            ::Katello::Resources::Candlepin::Pool.get_for_owner(organization.label).each do |subscription|
              next unless subscription['productName'] == name
              next unless sku.empty? || subscription['productId'] == sku
              next unless subscription['quantity'] == -1 ||
                          subscription['quantity'] - subscription['consumed'] > 0

              begin
                content_host.subscribe(subscription['id'], quantity)
              rescue Exception => e
                puts _('Subscription \'%{name}\' could not be attached') % {:name => name}
              end
              break
            end
          end
        end
      end
    end
  end
end
