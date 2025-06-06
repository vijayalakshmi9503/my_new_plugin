# This file is part of the OpenProject plugin "employee_time_balance right now i have named it as my_new_plugin u can  change it as it needed".
#
# Plugin Name: Employee Time Balance
# Description: This plugin displays the leftover time for each employee based on the work packages assigned in each project.
# Author: Vijayalakshmi A
# License: GNU General Public License v3.0 (GPLv3)
# Copyright (C) 2025 Vijayalakshmi A


$:.push File.expand_path("../lib", __FILE__)
$:.push File.expand_path("../../lib", __dir__)

require "open_project/my_new_plugin/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "openproject-my_new_plugin"
  s.version     = OpenProject::MyNewPlugin::VERSION

  s.authors     = ["Vijayalakshmi A"]
  s.email       = "info@openproject.org"
  s.homepage    = "http://10.180.146.91:3000/my_new_plugin/employee_summary"  # TODO check this URL
  s.summary     = "OpenProject My New Plugin"
  s.description = "This plugin adds feature employee list to OpenProject, calculating assignable hours left for each employee in the project."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*"] + %w(CHANGELOG.md README.md)
end
