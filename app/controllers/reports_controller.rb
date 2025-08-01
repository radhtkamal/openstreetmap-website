class ReportsController < ApplicationController
  layout "site"

  before_action :authorize_web
  before_action :set_locale
  before_action :check_database_readable

  authorize_resource

  before_action :check_database_writable, :only => [:new, :create]

  def new
    if required_new_report_params_present?
      @report = Report.new
      @report.issue = Issue.find_or_initialize_by(create_new_report_params)
    else
      head :bad_request
    end
  end

  def create
    @report = current_user.reports.new(report_params)
    @report.issue = Issue
                    .create_with(:assigned_role => default_assigned_role)
                    .find_or_initialize_by(issue_params)

    if @report.save
      @report.issue.assigned_role = "administrator" if default_assigned_role == "administrator"
      @report.issue.reopen unless @report.issue.open?
      @report.issue.save!

      @report.issue.reported_user&.spam_check

      redirect_to helpers.reportable_url(@report.issue.reportable), :notice => t(".successful_report")
    else
      flash.now[:warning] = t(".provide_details")
      render :action => "new"
    end
  end

  private

  def required_new_report_params_present?
    create_new_report_params["reportable_id"].present? && create_new_report_params["reportable_type"].present?
  end

  def create_new_report_params
    params.permit(:reportable_id, :reportable_type)
  end

  def report_params
    params.expect(:report => [:details, :category])
  end

  def issue_params
    params.require(:report).require(:issue).permit(:reportable_id, :reportable_type)
  end

  def default_assigned_role
    case issue_params[:reportable_type]
    when "Note"
      "moderator"
    when "User"
      case report_params[:category]
      when "vandal" then "moderator"
      else "administrator"
      end
    else
      "administrator"
    end
  end
end
