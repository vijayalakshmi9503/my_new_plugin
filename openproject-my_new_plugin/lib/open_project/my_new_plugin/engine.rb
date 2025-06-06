# # Prevent load-order problems in case openproject-plugins is listed after a plugin in the Gemfile
# # or not at all
# require "open_project/plugins"



module OpenProject::MyNewPlugin
  class Engine < ::Rails::Engine
    engine_name :openproject_my_new_plugin

    include OpenProject::Plugins::ActsAsOpEngine
    isolate_namespace OpenProject::MyNewPlugin

    register "openproject-my_new_plugin",
             author_url: "https://10.180.146.91:3000",
             requires_openproject: ">= 6.0.0" do

      # Define project module and permissions
      project_module :my_new_plugin_module do
        permission :view_my_new_plugin,
                   { my_new_plugin_labels: [:index] },
                   permissible_on: [:project]
      end

      # Ensure User.current.allowed_to? exists and is called correctly
menu :project_menu, 
     :my_new_plugin_label, 
     { controller: '/open_project/my_new_plugin/employee_list', action: :index }, 
     caption: :"my_new_plugin_label", 
     param: :project_id, 
     icon: 'icon2 icon-bug', 
     html: { id: "my_new_plugin_label" }, 
     if: ->(project) {
       user = User.current
       Rails.logger.info "User #{user.login} checking menu visibility"
       user.respond_to?(:allowed_to?) && user.logged? && user.allowed_to?(:view_my_new_plugin, project)
     }
    end
  end
end