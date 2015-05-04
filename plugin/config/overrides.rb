Foreman::Application.routes.draw do
  scope :foreman_csv, :module => :csv do
    match '/csv' => 'foreman_csv#plugin', :via => :get
  end
end
