ForemanCSV::Engine.routes.draw do
  match '/:csv_page/(*path)', :to => 'foreman_csv#index'
  match '/csv/(*path)', :to => 'foreman_csv#index_ie'
end
