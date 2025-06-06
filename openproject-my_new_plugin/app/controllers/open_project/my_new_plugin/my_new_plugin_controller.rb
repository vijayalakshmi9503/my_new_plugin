module OpenProject
  module MyNewPlugin
    class MyNewPluginController < ::ApplicationController
      include PaginationHelper
  include Layout
  before_action { @current_menu_item = :employee_list }
  menu_item :backlogs, only: %i[index show]
  helper_method :calculate_weekdays
  no_authorization_required! :index, :robots, :update_daily_hours, :update_week_days

  current_menu_item :index do
    :backlogs
  end

  def index
    @daily_working_hours = 6
    project_id = params[:project_id]
    sprint_id = params[:sprint_id]

    @project = Project.find_by(id: project_id)

    if @project
      @employees = User
        .joins("LEFT JOIN work_packages ON users.id = work_packages.assigned_to_id
                LEFT JOIN statuses ON work_packages.status_id = statuses.id
                LEFT JOIN versions ON work_packages.version_id = versions.id")
        .where("work_packages.project_id = ?", @project.id)
        .where("versions.id = ?", sprint_id) # ✅ filter by sprint
        .select(
          "users.id AS user_id,
           CONCAT(users.firstname, ' ', users.lastname) AS employee_name,
           work_packages.id AS task_id,
           work_packages.subject AS task_name,
           statuses.name AS task_status,
           COALESCE(work_packages.estimated_hours, 0) AS estimated_hours,
           COALESCE(work_packages.done_ratio, 0) AS done_ratio,
           COALESCE(work_packages.remaining_hours, 0) AS remaining_hours,
           COALESCE(work_packages.week_days, NULL) AS stored_week_days,
           COALESCE(work_packages.daily_working_hrs, NULL) AS stored_daily_working_hrs,
           COALESCE(versions.name, 'No Sprint') AS sprint_name,
           versions.start_date AS sprint_start_date,
           versions.effective_date AS sprint_end_date,
           versions.id AS version_id"
        )
        .order("users.id, work_packages.id")
        .group("users.id, users.firstname, users.lastname, work_packages.id,
                work_packages.subject, statuses.name, versions.id, versions.name,
                versions.start_date, versions.effective_date, work_packages.estimated_hours,
                work_packages.done_ratio, work_packages.remaining_hours,
                work_packages.week_days, work_packages.daily_working_hrs")

      @grouped_data = @employees.group_by(&:user_id)

      @grouped_data.each_value do |tasks|
        first_task = tasks.first
        start_date = first_task.sprint_start_date
        end_date = first_task.sprint_end_date

        week_days_values = tasks.map(&:stored_week_days).compact.uniq
        daily_hours_values = tasks.map(&:stored_daily_working_hrs).compact.uniq

        weekdays = if week_days_values.length == 1
                     week_days_values.first.to_i
                   else
                     calculate_weekdays(start_date, end_date)
                   end

        daily_hours = if daily_hours_values.length == 1
                        daily_hours_values.first.to_i
                      else
                        @daily_working_hours
                      end

        total_available_hours = weekdays * daily_hours
        estimated_hours_sum = tasks.sum(&:estimated_hours)
        leftover_time = total_available_hours - estimated_hours_sum

        first_task.instance_variable_set(:@weekdays, weekdays)
        first_task.instance_variable_set(:@daily_hours, daily_hours)
        first_task.instance_variable_set(:@total_available_hours, total_available_hours)
        first_task.instance_variable_set(:@leftover_time, leftover_time)
      end
    else
      @employees = []
      @grouped_data = {}
    end
  end

  def update_daicly_hours
    user_id = params[:user_id]
    version_id = params[:version_id]
    daily_working_hrs = params[:daily_working_hrs].to_i
    weekdays = params[:week_days].to_i
    Rails.logger.debug { "user_id: #{user_id}, version_id: #{version_id}" }
    Rails.logger.debug { "daily_working_hrs: #{daily_working_hrs}, weekdays: #{weekdays}" }
    # Find all tasks for this user and sprint (version)
    user_tasks = WorkPackage.where(assigned_to_id: user_id, version_id: version_id)

    if user_tasks.exists?
      # Bulk update daily_working_hrs for all tasks
      user_tasks.update_all(daily_working_hrs: daily_working_hrs)

      # Get sprint details for reference
      sprint = user_tasks.first.version
      start_date = sprint.start_date
      end_date = sprint.effective_date
      Rails.logger.debug { "daily_working_hrs: #{daily_working_hrs.inspect} (#{daily_working_hrs.class})" }
      Rails.logger.debug { "weekdays: #{weekdays.inspect} (#{weekdays.class})" }

      raise "daily_working_hrs is nil or zero" if daily_working_hrs.nil? || daily_working_hrs == 0
      raise "weekdays is nil or zero" if weekdays.nil? || weekdays == 0

      # Calculate total available hours for the sprint
      total_available_hours = weekdays * daily_working_hrs

      estimated_hours_sum = user_tasks&.sum(&:estimated_hours) || 0
      Rails.logger.debug { "total_available_hours: #{estimated_hours_sum}" }
      Rails.logger.debug { "total_available_hours: #{estimated_hours_sum}" }
      # estimated_hours_sum = user_tasks.sum(&:estimated_hours)
      leftover_time = total_available_hours - estimated_hours_sum
      Rails.logger.debug { "total_available_hours: #{estimated_hours_sum}" }
      # Prepare task data for the response
      tasks_data = user_tasks.map do |task|
        {
          id: task.id,
          subject: task.subject,
          status: task.status.try(:name),
          estimated_hours: task.estimated_hours,
          daily_working_hrs: daily_working_hrs
        }
      end

      # Return the updated data as JSON
      render json: {
        status: "success",
        message: "Daily hours updated and total available hours recalculated.",
        sprint: {
          id: sprint.id,
          name: sprint.name,
          start_date: sprint.start_date,
          end_date: sprint.effective_date
        },
        total_available_hours: total_available_hours,
        estimated_hours_sum: estimated_hours_sum,
        leftover_time: leftover_time,
        weekdays: weekdays,
        tasks: tasks_data
      }
    else
      render json: { status: "error", message: "No workpackages found." }, status: :not_found
    end
  end

  def update_daily_hours
    user_id = params[:user_id]
    version_id = params[:version_id]
    daily_working_hrs = params[:daily_working_hrs].to_i
    weekdays = params[:week_days].to_i

    Rails.logger.debug { "user_id: #{user_id}, version_id: #{version_id}" }
    Rails.logger.debug { "daily_working_hrs: #{daily_working_hrs}, weekdays: #{weekdays}" }

    user_tasks = WorkPackage.where(assigned_to_id: user_id, version_id: version_id)

    if user_tasks.exists?
      # Update all tasks with the new daily_working_hrs
      user_tasks.update_all(daily_working_hrs: daily_working_hrs)

      sprint = user_tasks.first.version

      raise "daily_working_hrs is nil or zero" if daily_working_hrs <= 0
      raise "weekdays is nil or zero" if weekdays <= 0

      task_count = user_tasks.count

      # Calculate using input values
      total_available_hours = daily_working_hrs * weekdays * task_count
      daily_working_hrs_sum = daily_working_hrs * task_count
      estimated_hours_sum = user_tasks.sum(:estimated_hours).to_f

      leftover_time = total_available_hours - estimated_hours_sum

      tasks_data = user_tasks.map do |task|
        {
          id: task.id,
          subject: task.subject,
          status: task.status.try(:name),
          estimated_hours: task.estimated_hours,
          daily_working_hrs: task.daily_working_hrs,
          week_days: task.week_days
        }
      end

      render json: {
        status: "success",
        message: "Daily working hours updated successfully.",
        sprint: {
          id: sprint.id,
          name: sprint.name,
          start_date: sprint.start_date,
          end_date: sprint.effective_date
        },
        total_available_hours: total_available_hours,
        estimated_hours_sum: estimated_hours_sum,
        daily_working_hrs_sum: daily_working_hrs_sum,
        leftover_time: leftover_time,
        weekdays: weekdays,
        tasks: tasks_data
      }
    else
      render json: { status: "error", message: "No workpackages found." }, status: :not_found
    end
  end

  def updaste_daily_hours
    user_id = params[:user_id]
    version_id = params[:version_id]
    daily_working_hrs = params[:daily_working_hrs].to_i
    weekdays = params[:week_days].to_i

    Rails.logger.debug { "user_id: #{user_id}, version_id: #{version_id}" }
    Rails.logger.debug { "daily_working_hrs: #{daily_working_hrs}, weekdays: #{weekdays}" }

    user_tasks = WorkPackage.where(assigned_to_id: user_id, version_id: version_id)

    if user_tasks.exists?
      # Bulk update daily_working_hrs for all tasks
      user_tasks.update_all(daily_working_hrs: daily_working_hrs)

      sprint = user_tasks.first.version
      start_date = sprint.start_date
      end_date = sprint.effective_date

      raise "daily_working_hrs is nil or zero" if daily_working_hrs.nil? || daily_working_hrs == 0
      raise "weekdays is nil or zero" if weekdays.nil? || weekdays == 0

      # Calculate total_available_hours and estimated_hours_sum (safe version)
      total_available_hours = 0
      estimated_hours_sum = 0

      user_tasks.each do |task|
        task_daily_hrs = task.daily_working_hrs || 0
        task_week_days = task.week_days.to_i
        total_available_hours += task_daily_hrs * task_week_days
        estimated_hours_sum += (task.estimated_hours || 0).to_f
      end

      leftover_time = total_available_hours - estimated_hours_sum

      tasks_data = user_tasks.map do |task|
        {
          id: task.id,
          subject: task.subject,
          status: task.status.try(:name),
          estimated_hours: task.estimated_hours,
          daily_working_hrs: task.daily_working_hrs
        }
      end

      render json: {
        status: "success",
        message: "Daily hours updated and total available hours recalculated.",
        sprint: {
          id: sprint.id,
          name: sprint.name,
          start_date: sprint.start_date,
          end_date: sprint.effective_date
        },
        total_available_hours: total_available_hours,
        estimated_hours_sum: estimated_hours_sum,
        leftover_time: leftover_time,
        weekdays: weekdays,
        tasks: tasks_data
      }
    else
      render json: { status: "error", message: "No workpackages found." }, status: :not_found
    end
  end

  def update_week_days
    user_id = params[:user_id]
    version_id = params[:version_id]
    week_days = params[:week_days]

    # Find all workpackages (tasks) for this user and sprint
    user_tasks = WorkPackage.where(assigned_to_id: user_id, version_id: version_id)

    if user_tasks.exists?
      # Bulk update week_days for all matching tasks
      user_tasks.update_all(week_days: week_days)

      sprint = user_tasks.first.version

      tasks_data = user_tasks.map do |task|
        {
          id: task.id,
          subject: task.subject,
          status: task.status.try(:name),
          estimated_hours: task.estimated_hours,
          week_days: week_days
        }
      end

      # Calculate total_available_hours and leftover_time
      # Assuming `daily_working_hrs` is available on each task, you can calculate these values
      total_available_hours = 0
      estimated_hours_sum = 0
      user_tasks.each do |task|
        daily_hours = task.daily_working_hrs || 0 # Default to 0 if no daily_working_hrs is set
        weekdays = task.week_days.to_i # Convert week_days to integer (if it's stored as a string)
        total_available_hours += weekdays * daily_hours
        estimated_hours_sum += task.estimated_hours || 0
      end

      leftover_time = total_available_hours - estimated_hours_sum

      render json: {
        status: "success",
        message: "week_days updated for all related tasks.",
        sprint: {
          id: sprint.id,
          name: sprint.name,
          start_date: sprint.start_date
        },
        tasks: tasks_data,
        total_available_hours: total_available_hours,
        estimated_hours_sum: estimated_hours_sum,
        leftover_time: leftover_time
      }
    else
      render json: { status: "error", message: "No workpackages found." }, status: :not_found
    end
  end

  def calculate_weekdays(start_date, end_date)
    start_date, end_date = [start_date, end_date].sort
    weekdays_count = 0
    (start_date..end_date).each do |date|
      weekdays_count += 1 unless date.saturday? || date.sunday?
    end
    weekdays_count
  end

    end
  end
end
