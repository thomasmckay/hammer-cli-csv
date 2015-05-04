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

module ForemanCSV
  class Api::V2::SpliceController < ::Api::V2::BaseController
    respond_to :json
    before_filter :authorize

    api :PUT, "/splice", N_("Upload splice CSV file")
    param :content, File, :required => true, :desc => N_("CSV file contents")
    def upload
      render :nothing => true
    end
  end
end
