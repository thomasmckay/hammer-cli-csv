Foreman::Application.routes.draw do
  mount ForemanCSV::Engine, :at => '/', :as => 'csv'
end
