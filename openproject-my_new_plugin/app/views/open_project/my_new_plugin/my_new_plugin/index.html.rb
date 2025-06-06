<%=
  render Primer::OpenProject::PageHeader.new do |header|
    header.with_title { t(:label_employee_list) }
    header.with_breadcrumbs([*([ href: home_path, text: organization_name ] unless @project),
                             *([ href: project_overview_path(@project.id), text: @project.name ] if @project),
                             t(:label_employee_list)])
  end
%>
<%= nonced_javascript_include_tag 'jquery.js' %>
<%= nonced_javascript_include_tag 'dataTables.min.js' %>
<%= stylesheet_link_tag 'dataTables.dataTables.min.css' %>
<% if @employees.present? %>
  <% first = @employees.first %>
  <div style="color: #101010eb; ">
    <div><strong style="font-size:20px;"><%= first.sprint_name %> Planning Details</strong></div>
    <div><strong style="font-size: 15px; color: #6e6c66;">Length in Workdays</strong>- <%= first.instance_variable_get(:@weekdays) %></div>
  </div>
<% else %>
  <h3 style="text-align: center;">Sprints shown for tasks assigned to user only — no sprint data available.</h3>
<% end %>
<% first_task = @grouped_data.values.flatten.first %>  <!-- Get the first task from the data -->
<% first_task = @grouped_data.values.flatten.first if @grouped_data.present? %>
<% if first_task %>
  <input type="text" id="version-id-input" value="<%= first_task.version_id %>" readonly style="display: none;" />
<% else %>
  <input type="text" id="version-id-input" value="" readonly style="display: none;" />
<% end %>

<table border="1" id="project-table" class="generic-tablee" width="100%" data-controller="table-highlighting">
    <thead class="-sticky" style="height: 40px;">
      <tr style="border-top: 2px solid #dce2e7; border-bottom: 2px solid #dce2e7; border-left: 2px solid #dce2e7; border-right: 2px solid #dce2e7;">
          <th style="border: 2px solid #dce2e7;">Team</th>
     
          <th style="border: 2px solid #dce2e7;">Available Workdays in Sprint *</th>
          <th style="border: 2px solid #dce2e7;">Average Available Hours per Day</th> 
          <th style="border: 2px solid #dce2e7;">Total Available Hours</th>
          <th style="border: 2px solid #dce2e7;">Allocated Hours in Sprint</th>
          <th style="border: 2px solid #dce2e7;">Assignable Hours</th> 
      </tr>
    </thead>
    <tbody style="border: 2px solid #dce2e7;">
      <% @grouped_data.each do |_project_id, employees| %>
        <% employees.group_by(&:user_id).each do |user_id, tasks| %>
          <% first_task = tasks.first %>
          <tr>
              <td style="border-left: 2px solid #dce2e7;"><%= first_task.employee_name %></td>
              <td style="border-left: 2px solid #dce2e7;">
                <input type="number"
                name="weekdays[<%= user_id %>]"
                class="weekdays-input"
                value="<%= first_task.instance_variable_get(:@weekdays) %>"
                min="1"
                max="<%= calculate_weekdays(first_task.sprint_start_date, first_task.sprint_end_date) %>"
                style="width: 60px;" />
              </td>
              <!-- Editable Daily Working Hours -->
              <td style="border-left: 2px solid #dce2e7;">
                <input type="number"
                      name="daily_hours[<%= user_id %>]"
                      class="daily-hours-input"
                      value="<%= first_task.instance_variable_get(:@daily_hours)  %>"
                      min="1"
                      style="width: 60px;" />
              </td>
              <td style="border-left: 2px solid #dce2e7;">
                <%= first_task.instance_variable_get(:@total_available_hours) || @daily_working_hours * weekdays_between(first_task.sprint_start_date, first_task.sprint_end_date) %>
              </td>
              <td style="border-left: 2px solid #dce2e7;"><%= tasks.sum(&:estimated_hours) %></td>
              <td style="border-left: 2px solid #dce2e7;">
                  <span style="
                        <% if first_task.instance_variable_get(:@leftover_time).to_f >= 0 %>
                            background-color: green;
                        <% else %>
                            background-color: red;
                        <% end %>
                        padding: 2px 5px; border-radius: 3px; color: white;">
                    <%= first_task.instance_variable_get(:@leftover_time) || 0 %>
                  </span>
              </td>
          </tr>
        <% end %>
      <% end %>
    </tbody>
</table>

<%= nonced_javascript_tag do %>
document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('.weekdays-input').forEach(function (input) {
      input.addEventListener('input', function () {
        let max = parseInt(input.getAttribute('max'));
        if (parseInt(input.value) > max) {
          input.value = max;
        }
      });
    });
});

document.addEventListener("DOMContentLoaded", function () {
  const table = document.getElementById('project-table');
    if (table) {
      $('#project-table').DataTable({
        paging: true,
        searching: true,
        ordering: true,
        pageLength: 10,
        lengthChange: false
      });
    }
});

document.querySelectorAll('.daily-hours-input').forEach(input => {
  input.addEventListener('change', function () {
    const userId = this.name.match(/\d+/)[0]; // Extract user ID from name
    const newHours = this.value;
    // Get version (sprint name) from the same row
    const row = this.closest('tr');
    var versionId = document.getElementById('version-id-input').value;
    const weekdaysInput = row.querySelector('.weekdays-input');
const week_days = weekdaysInput ? weekdaysInput.value : null;

console.log('Weekdays:', week_days);
    // Send AJAX request to update server
    fetch('/update_daily_hours', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        user_id: userId,
        version_id:versionId,
        daily_working_hrs: newHours,
        week_days: week_days
      })
    })
    .then(response => {
      if (!response.ok) throw new Error('Failed to update hours');
      return response.json();
    })
    .then(data => {
      const totalHoursCell = row.querySelector('td:nth-child(4)'); // Total Available Hours
      const estimatedHoursCell = row.querySelector('td:nth-child(5)'); // Estimated Hours
      const leftoverTimeCell = row.querySelector('td:nth-child(6) span'); // Leftover Time
      // Update total available hours
      if (totalHoursCell && data.total_available_hours !== undefined) {
        totalHoursCell.textContent = data.total_available_hours;
      }
      // Update estimated hours sum
      if (estimatedHoursCell && data.estimated_hours_sum !== undefined) {
        estimatedHoursCell.textContent = data.estimated_hours_sum;
      }
      // Update leftover time with color change based on condition
      if (leftoverTimeCell && data.leftover_time !== undefined) {
        leftoverTimeCell.textContent = data.leftover_time;
      // Check if leftover time exceeds total available hours, change color accordingly
      if (data.leftover_time >= 0) {
          leftoverTimeCell.style.backgroundColor = 'green';
          } else {
            leftoverTimeCell.style.backgroundColor = 'red';
          }
      }
    })
    .catch(err => {
      console.error('Error updating daily hours:', err);
    });
  });
});

document.querySelectorAll('.weekdays-input').forEach(input => {
  input.addEventListener('change', function () {
    const userId = this.name.match(/\d+/)[0]; // Extract user ID from name
    const newHours = this.value;
    // Get version (sprint name) from the same row
    const row = this.closest('tr');
  ; // Adjust index as needed
    var versionId = document.getElementById('version-id-input').value;
    // Send AJAX request to update server
    fetch('/update_week_days', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        user_id: userId,
        version_id:versionId,
        week_days: newHours
      })
    })
    .then(response => {
      if (!response.ok) throw new Error('Failed to update hours');
      return response.json();
    })
    .then(data => {
      // Find the corresponding row and update the values in the table
      const totalAvailableHoursCell = row.querySelector('td:nth-child(4)');
      const estimatedHoursCell = row.querySelector('td:nth-child(5)');
      const leftoverTimeCell = row.querySelector('td:nth-child(6) span');
      // Update the total available hours, estimated hours, and leftover time
      totalAvailableHoursCell.innerText = data.total_available_hours;
      estimatedHoursCell.innerText = data.estimated_hours_sum;
      // Update the leftover time with color based on the condition
      leftoverTimeCell.innerText = data.leftover_time;
      if (data.leftover_time >= 0) {
          leftoverTimeCell.style.backgroundColor = 'green';
        } else {
          leftoverTimeCell.style.backgroundColor = 'red';
        }
    })
    .catch(err => {
      console.error('Error updating daily hours:', err);
    });
  });
});

<% end %>