OpenProject::MyNewPlugin::Engine.routes.draw do
  get 'employee_summary', to: 'my_new_plugin#index'
end