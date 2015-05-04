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

require 'json'
require 'csv'

module Actions
  module ForemanCSV
    module Import
      class ImportAction < Actions::AbstractAsyncTask
        NAME = 'Name'
        COUNT = 'Count'

        def option_prefix
          '' # TODO: input[:prefix]
        end

        def namify(name_format, number = 0)
          if name_format.index('%')
            name = name_format % number
          else
            name = name_format
          end
          name = "#{option_prefix}#{name}" if option_prefix
          name
        end

        def labelize(name)
          name.gsub(/[^a-z0-9\-_]/i, '_')
        end

        def thread_import(filename, name_column=nil)
          option_threads = 1  # TODO: should we thread this ever, or break by dynflow?

          csv = []
          CSV.foreach(filename, {
              :skip_blanks => true,
              :headers => :first_row,
              :return_headers => false
          }) do |line|
            csv << line
          end
          lines_per_thread = csv.length / option_threads.to_i + 1
          splits = []

          option_threads.to_i.times do |current_thread|
            start_index = ((current_thread) * lines_per_thread).to_i
            finish_index = ((current_thread + 1) * lines_per_thread).to_i
            finish_index = csv.length if finish_index > csv.length
            if start_index <= finish_index
              lines = csv[start_index...finish_index].clone
              splits << Thread.new do
                lines.each do |line|
                  if line[name_column || NAME][0] != '#'
                    yield line
                  end
                end
              end
            end

            splits.each do |thread|
              thread.join
            end
          end
        end

        def foreman_organization(options = {})
          @organizations ||= {}

          if options[:name]
            return nil if options[:name].nil? || options[:name].empty?
            options[:id] = @organizations[options[:name]]
            if !options[:id]
              organization = Organization.where(:name => options[:name]).first
              raise "Organization '#{options[:name]}' not found" if organization.nil?
              options[:id] = organization.id
              @organizations[options[:name]] = options[:id]
            end
            result = options[:id]
          else
            return nil if options[:id].nil?
            options[:name] = @organizations.key(options[:id])
            if !options[:name]
              organization = Organization.where(:name => options[:name]).first
              raise "Organization 'id=#{options[:id]}' not found" if !organization || organization.empty?
              options[:name] = organization.name
              @organizations[options[:name]] = options[:id]
            end
            result = options[:name]
          end

          result
        end

      end
    end
  end
end
