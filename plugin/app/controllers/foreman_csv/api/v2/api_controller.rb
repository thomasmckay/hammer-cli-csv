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

require 'strong_parameters'

module ForemanCSV
  class Api::V2::ApiController < ::Api::V2::BaseController
    include Katello::Concerns::Api::ApiController
    include Katello::Api::Version2
    include Katello::Api::V2::Rendering
    include Katello::Api::V2::ErrorHandling

    # support for session (thread-local) variables must be the last filter in this class
    include Foreman::ThreadSession::Cleaner

    respond_to :json
    before_filter :authorize

    resource_description do
      resource_id 'csv'
      api_version 'v2'
      api_base_url '/csv/api/v2'
    end
  end
end
