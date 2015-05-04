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
    class ImportContentHosts < Actions::AbstractAsyncTask
      middleware.use Actions::Middleware::KeepCurrentUser

      def plan(content)
        begin
          temp_file = File.new(File.join("#{Rails.root}/tmp", "csv_#{SecureRandom.hex(10)}.csv"),
                               'w+', 0600)
          temp_file.write content.read
        ensure
          temp_file.close
        end

        sequence do
          concurrence do
            plan_action(Actions::ForemanCSV::Import::ContentHosts, temp_file.path)
          end
          plan_action(Actions::ForemanCSV::Import::RemoveFile, temp_file.path)
        end
      end

      def humanized_name
        _("Import CSV - content-hosts")
      end
    end
  end
end
