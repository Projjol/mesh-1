class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  before_action :permit_all

  def get_dt_oauth
    session["user_id"] = params[:user_id]
    redirect_to User::SSO_URL
  end

  def incoming_digitaltown
    user = User.find(session["user_id"])
    user.initiate_sso(params[:code])
    render html: "mama"
  end

  def incoming_slack
    render html: params[:challenge]
    # render html: "mama"
  end

  def permit_all
    params.permit!  
  end


end
