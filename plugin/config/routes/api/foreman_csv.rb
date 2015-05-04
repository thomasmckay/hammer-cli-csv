ForemanCSV::Engine.routes.draw do
  scope :foreman_csv, :path => '/csv' do
    namespace :api do
      scope "(:api_version)", :module => :v2, :defaults => {:api_version => 'v2'}, :api_version => /v2/, :constraints => ApiConstraints.new(:version => 2, :default => true) do
        match '/content_hosts' => 'content_hosts#import_content_hosts', :via => :post
      end
    end
  end
end
