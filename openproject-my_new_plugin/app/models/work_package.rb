class AddDailyWorkingHrsAndWeekDaysToWorkPackages < ActiveRecord::Migration[7.1]
  def change
    add_column :work_packages, :daily_working_hrs, :integer
    add_column :work_packages, :week_days, :integer
  end
end
