class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  before_action :permit_all

  def get_dt_oauth
    session["user_id"] = params[:user_id]
    redirect_to User::SSO_URL
  end

  def incoming_telegram
    # hash_params = params.to_h
    # Rails.cache.write("tchus", hash_params)
    # chat_id = hash_params.message.chat.id rescue hash_params.callback_query.message.chat.id
    # text = hash_params.message.text rescue nil
    # payload = hash_params.callback_query.data rescue nil
    # user = User.find_by(telegram_id: chat_id) rescue nil
    # if user.blank?
    #   User.create_from_message_telegram(chat_id)
    # elsif !text.blank?
    #   user.current_bot = "telegram"
    #   user.save
    #   user.start_flow({text: text, location_coordinates: {}, quick_reply: {}})
    # elsif !payload.blank?
    #   user.current_bot = "telegram"
    #   user.save
    #   user.on_postback({payload: payload})
    # end
    render json: {success: true}
  end

  def incoming_digitaltown
    user = User.find(session["user_id"])
    user.initiate_sso(params[:code])
    render html: "<img src=\"/success.png\"> </image>".html_safe
  end

  def incoming_slack
    render html: params[:challenge]
    # render html: "mama"
  end

  def permit_all
    params.permit!  
  end


end
