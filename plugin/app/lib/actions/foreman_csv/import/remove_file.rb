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
      class RemoveFile < Actions::AbstractAsyncTask
        def plan(file_name)
          plan_self(:file_name => file_name)
        end

        def run
          print _('Removing temporary CSV file...')
          File.delete(input[:file_name])
          puts _('done')
        end
      end
    end
  end
end
