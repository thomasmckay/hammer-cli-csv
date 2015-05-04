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
  class Api::V2::ContentHostsController < Api::V2::ApiController
    skip_before_filter :check_content_type, :only => [:import_content_hosts]

    def resource_class
      @resource_class = ::Katello::System
    end

    api :POST, "/content_hosts", N_("Upload content-hosts CSV file")
    param :content, File, :required => true, :desc => N_("CSV file contents")
    def import_content_hosts
      task = async_task(::Actions::ForemanCSV::ImportContentHosts, params[:content])
      respond_for_async :resource => task
    end
  end
end
