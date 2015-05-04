require_dependency 'foreman_csv/application_controller'

module ForemanCSV
  class ForemanCSVController < ForemanCSV::ApplicationController
    before_filter :authorize

    def index
      render 'foreman_csv/layouts/application', :layout => false
    end

    def plugin
      render 'foreman_csv/layouts/application', :layout => false, :anchor => '/csv'
    end
  end
end
