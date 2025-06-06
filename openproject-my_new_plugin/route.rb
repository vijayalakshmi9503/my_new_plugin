  
 # ================================
# Vijayalakshmi - Employee List Plugin Routes
# ================================

# Mount the plugin engine under its namespace
mount OpenProject::MyNewPlugin::Engine => "/my_new_plugin"

# Custom routes for managing employee working details
get  "employee_list",            to: "employee_list#index"
post "update_daily_hours",       to: "employee_list#update_daily_hours"
post "update_week_days",         to: "employee_list#update_week_days"

# ================================
# End of Vijayalakshmi's Routes
# ================================