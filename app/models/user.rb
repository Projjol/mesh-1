class User < ActiveRecord::Base
  store_accessor :json_store, :profile_pic, :state, :lang, :latlong, :delivery, :delivery_distance, :display_name, :phone, :sso_details, :auth, :wallet_from, :type_of_business, :car_details, :car_no, :house_images, :profession, :house_details, :email
  has_and_belongs_to_many :groceries, join_table: "user_grocery_mappings"
  has_many :orders
  scope :business, -> {where(role: "business")}
  scope :stores, -> {business.where("(json_store ->> 'type_of_business') = ?", "store")}
  scope :drivers, -> {business.where("(json_store ->> 'type_of_business') = ?", "uberkiller")}
  scope :airbnbkillers, -> {business.where("(json_store ->> 'type_of_business') = ?", "airbnbkiller")}
  scope :professional_services, -> {business.where("(json_store ->> 'type_of_business') = ?", "professional_services")}
  scope :housejoykillers, -> {business.where("(json_store ->> 'type_of_business') = ?", "housejoykiller")}
  # scope :drivers, -> {business.where("(json_store ->> 'type_of_business') = ?", "uberkiller")}

  def self.create_from_message(message)
    user = User.create(fb_id: message.sender['id'], state: "state_ask_for_lang")
    user.save_fb_profile
    # user.send_welcome_message(message)
    user.send_select_language(message)
  end

  def self.find_by_email(email)
    User.where("(json_store ->> 'email') = ?", email).last
  end

  after_initialize :init

  def init
    self.latlong = [0,0] if latlong.blank?
  end

  def initiate_sso(code)
    s = "curl --request POST \
  --url https://api.digitaltown.com/sso/token \
  --data '{\"grant_type\":\"authorization_code\",\"client_id\":\"#{ENV["DT_CLIENT_ID"]}\",\"client_secret\":\"#{ENV["DT_CLIENT_SECRET"]}\",\"code\":\"#{code}\",\"redirect_uri\":\"https://9df52743.ngrok.io/incoming_digitaltown\"}' -H 'content-type: application/json'"
  puts "="*100
  puts s
    res = `#{s}`
    update_attributes(auth: JSON.parse(res))
    sso_details = get_details_from_digitaltown
    update_attributes(sso_details: sso_details, state: "state_done", first_name: sso_details["first_name"], last_name: sso_details["last_name"], email: sso_details["email"])
    send_message(text: "You are successfully logged in.")
    if role == "business"
      Business.ask_for_business(self)
    else
    end
  end

  def self.curl(s)
    puts "============"
    puts "curl #{s}"
    res = `curl #{s} -H 'content-type: application/json'`
    puts "============"
    puts res
    puts "============"
    return res
  end

  def get_details_from_digitaltown
    res = User.curl "--request GET \
  --url https://api.digitaltown.com/sso/users \
  --header 'authorization: Bearer #{get_access_token}'"
    return JSON.parse(res)
  end

  def add_wallet(currency_id, wallet_type_id, wallet_category_id, wallet_name, wallet_note)
    res = User.curl "--request POST \
  --url https://wallet-api.digitaltown.com/api/v1/wallets \
  --header 'authorization: Bearer #{get_access_token}' \
  --data '{\"userID\":\"#{get_dt_user_id}\",\"wallet_currency_id\":#{currency_id},\"wallet_type_id\":\"#{wallet_type_id}\",\"wallet_category_id\":\"#{wallet_category_id}\",\"wallet_name\":\"#{wallet_name}\",\"wallet_note\":\"#{wallet_note}\",\"wallet_active\":1,\"wallet_primary\":\"0\", \"wallet_balance\":\"12.32\"}'"
    return JSON.parse(res)
  end

 def update_wallet(wallet_id, wallet_type_id, wallet_category_id, wallet_name, wallet_note)
    res = User.curl "--request PUT \
  --url https://wallet-api.digitaltown.com/api/v1/wallets/#{wallet_id}?userID=#{get_dt_user_id} \
  --header 'authorization: Bearer #{get_access_token}' \
  --data '{\"wallet_type_id\":\"#{wallet_type_id}\",\"wallet_category_id\":\"#{wallet_category_id}\",\"wallet_name\":\"#{wallet_name}\",\"wallet_note\":\"#{wallet_note}\",\"wallet_active\":1,\"wallet_primary\":\"0\"}'"
    return JSON.parse(res)
  end

  def get_wallets
    res = User.curl "--request GET \
  --url https://wallet-api.digitaltown.com/api/v1/wallets?userID=#{get_dt_user_id} \
  --header 'authorization: Bearer #{get_access_token}'"
    return JSON.parse(res)
  end

  def get_inactive_wallets
    res = User.curl "--request GET \
  --url https://wallet-api.digitaltown.com/api/v1/wallets/inactives?userID=#{get_dt_user_id} \
  --header 'authorization: Bearer #{get_access_token}'"
    return JSON.parse(res)
  end

  def activate_wallet(wallet_id)
    res = User.curl "--request PUT \
  --url https://wallet-api.digitaltown.com/api/v1/wallets/#{wallet_id}/activate?userID=#{get_dt_user_id} \
  --header 'authorization: Bearer #{get_access_token}'"
    return JSON.parse(res)
  end

  def deactivate_wallet(wallet_id)
    res = User.curl "--request PUT \
  --url https://wallet-api.digitaltown.com/api/v1/wallets/#{wallet_id}/deactivate?userID=#{get_dt_user_id} \
  --header 'authorization: Bearer #{get_access_token}'"
    return JSON.parse(res)
  end

  def wallet_transfer(from, to, amount)
    res = User.curl "--request POST \
  --url 'https://wallet-api.digitaltown.com/api/v1/wallets/#{from}/transfers?userID=#{get_dt_user_id}' \
  --header 'authorization: Bearer #{get_access_token}' \
  --data '{\"wallet_to\":#{to},\"wallet_amount\":\"#{amount}\"}'"
    
  end

  def get_wallet(wallet_id)
    res = User.curl "--request GET \
  --url https://wallet-api.digitaltown.com/api/v1/wallets/#{wallet_id}?userID=#{get_dt_user_id} \
  --header 'authorization: Bearer #{get_access_token}'"
    return JSON.parse(res)
  end

  def delete_wallet(wallet_id)
    res = User.curl "--request DELETE \
  --url https://wallet-api.digitaltown.com/api/v1/wallets/#{wallet_id}?userID=#{get_dt_user_id} \
  --header 'authorization: Bearer #{get_access_token}'"
    return JSON.parse(res)
  end

  def get_dt_user_id
    sso_details["id"]
  end
  
 def clients(user_id)
    res = User.curl "--request GET \
  --url https://api.digitaltown.com/sso/users/clients?userID=#{user_id} \
  --header 'authorization: Bearer #{get_access_token}'"
    return JSON.parse(res)
  end

  def get_access_token
    return auth["access_token"]
  end

  def refresh_access_token
    
  end


  def delivery?
    !!delivery
  end

  def send_select_language(message)
    buttons = {"set_english" => I18n.t('english'),  "set_hindi" => I18n.t('hindi')}
    send_buttons(message, I18n.t('select_language'), buttons)
  end

  def get_fb_profile
    res = `curl https://graph.facebook.com/v2.6/#{fb_id}?access_token=#{ENV['ACCESS_TOKEN']}`
    json_res = JSON.parse(res)
    return json_res
  end

  def self.process_csv
    res = Hash.new([])
    grocery_csv = CSV.read("grocery.csv")
    processd_csv = grocery_csv.map{|a| a.map{|b| b.to_s.sub("· ", "")}}
    processd_csv = processd_csv.transpose
    processd_csv.each do |row|
      header = true
      row.each do |item|
        if item.blank?
          header = true
          next
        else
          if header
            res[item]
          end
        end
      end
    end
  end

  # [
  #       {
  #         "title": "Chus title",
  #         "subtitle": "Chus subtitle",
  #         "buttons": [
  #           {
  #             "title": "View",
  #             "type": "postback",
  #             "payload": "chussandas"
  #           }
  #         ]
  #       },{
  #         "title": "Chus title1",
  #         "subtitle": "Chus subtitle1",
          
  #         "buttons": [
  #           {
  #             "title": "View",
  #             "type": "postback",
  #             "payload": "chussandas"
  #           }
  #         ]
  #       }
  #     ]
  
  # buttons
  # [
  #       {
  #         "title": "View More",
  #         "type": "postback",
  #         "payload": "payload"
  #       }
  #     ]
  def self.create_group(count)
    group = []
    while count != 0
      if count%4 == 0
        group << 4
        count = count - 4
      elsif count%4 == 1
        group << 2
        group << 3
        count = count - 5
      else
        group << count%4
        count = count - (count%4)
      end
    end
    return group.reverse
  end

  def self.send_list(message, elements, buttons)
    # message.reply(
    #   "attachment": 
    #   {
    #     "type": "template",
    #     "payload": {
    #       "template_type": "list",
    #       "top_element_style": "compact",
    #       "elements": elements[0..3],
    #       "buttons": buttons
    #     }
    # })   
    if elements.count == 1
      elements[0][:buttons] += buttons if !buttons.blank?
      message.reply(
      "attachment": 
      {
        "type": "template",
        "payload": {
          "template_type": "generic",
          "elements": elements
        }
      })
      return 
    end
    i = 0
    group = User.create_group(elements.count)
    group.each_with_index do |count, index|
      j = i + count
      if index != (group.count - 1)
        buttons_ = []
      else
        buttons_ = buttons
      end
      message.reply(
      "attachment": 
      {
        "type": "template",
        "payload": {
          "template_type": "list",
          "top_element_style": "compact",
          "elements": elements[i..j-1],
          "buttons": buttons_
        }
      })
      i = j
    end
  end
def send_list(elements, buttons)
    # message.reply(
    #   "attachment": 
    #   {
    #     "type": "template",
    #     "payload": {
    #       "template_type": "list",
    #       "top_element_style": "compact",
    #       "elements": elements[0..3],
    #       "buttons": buttons
    #     }
    # })   
    if elements.count == 1
      elements[0][:buttons] += buttons if !buttons.blank?
      message.reply(
      "attachment": 
      {
        "type": "template",
        "payload": {
          "template_type": "generic",
          "elements": elements
        }
      })
      return 
    end
    i = 0
    group = User.create_group(elements.count)
    group.each_with_index do |count, index|
      j = i + count
      if index != (group.count - 1)
        buttons_ = []
      else
        buttons_ = buttons
      end
      send_message(
      "attachment": 
      {
        "type": "template",
        "payload": {
          "template_type": "list",
          "top_element_style": "compact",
          "elements": elements[i..j-1],
          "buttons": buttons_
        }
      })
      i = j
    end
  end

  def save_fb_profile
    res = get_fb_profile
    self.first_name = res["first_name"]
    self.last_name = res["last_name"]
    self.profile_pic = res["profile_pic"]
    self.save
  end

  def send_buttons(message, text, buttons_hash)
    buttons = []
    buttons_hash.each do |k,v|
      buttons << {type: 'postback', title: v, payload: k}
    end
    message.reply(
      attachment: {
       type: 'template',
        payload: {
          template_type: 'button',
          text: text,
          buttons: buttons
        }
      }
    )
  end

  def send_welcome_message(message)
    # message.reply(text: I18n.t('hello', name: first_name))
    buttons = {"continue_business_owner" => I18n.t('continue_business_owner'),  "continue_customer" => I18n.t('continue_customer')}
    send_buttons(message, I18n.t('hello', name: first_name), buttons)
  end

  def ask_for_login
    send_message(
      attachment: {
       type: 'template',
        payload: {
          template_type: 'button',
          text: "Please login through Digital Town",
          buttons: [
            {
              type: "web_url",
              url: Rails.application.routes.url_helpers.get_dt_oauth_url(host: ENV["HOST"], user_id: id),
              title: "Login",
              webview_height_ratio: "tall"
            }
          ]
        }
      }
    )
  end
  CURRENCY = JSON.parse(File.read("currency.json"))["result"].first["data"]

  def get_currency(currency_id)
    # CURRENCY.
    # {"id"=>1, "cur_country"=>"United Arab Emirates", "cur_currency"=>"United Arab Emirates Dirham", "cur_code"=>"AED", "cur_symbol"=>"", "cur_thousand_separator"=>nil, "cur_decimal_separator"=>nil, "cur_country_iso_2"=>"AE", "cur_country_iso_3"=>"ARE", "cur_weight"=>"1.00", "cur_active"=>1, "created_at"=>"2017-06-10 21:50:15", "updated_at"=>"2017-06-10 21:50:15", "deleted_at"=>nil}
    res = nil
    CURRENCY.each do |currency_hash|
      if currency_id == currency_hash.id
        return currency_hash
      end
    end
    return res

  end

  def send_more_actions_wallet(wallet_id)
    elements = []
    wallet_hash = get_wallet(wallet_id).result.last
    wallet_id = wallet_hash.wallet_id
      
      buttons = []
      
      buttons << {
        title: "Update",
        type: "postback",
        payload: "update_wallet:#{wallet_id}"
      }
      buttons << {
        title: "Delete",
        type: "postback",
        payload: "delete_wallet:#{wallet_id}"
      }
      activation_title = wallet_hash.wallet_active == 1 ? "Deactivate" : "Activate"
      activation_payload = wallet_hash.wallet_active == 1 ? "deactivate_wallet" : "activate_wallet"
      buttons << {
        title: activation_title,
        type: "postback",
        payload: "#{activation_payload}:#{wallet_id}"
      }
      elements << {
        title: wallet_title(wallet_hash),
        subtitle: wallet_subtitle(wallet_hash),
        buttons: buttons
      }
      send_generic(elements)  
  end

  def wallet_title(wallet_hash)
    currency = get_currency(wallet_hash.wallet_currency_id)
    "#{wallet_hash.wallet_name}#{"(Primary)" if (wallet_hash.wallet_primary == 1)} - #{currency.cur_symbol} #{wallet_hash.wallet_balance}"
  end

  def wallet_subtitle(wallet_hash)
    res = wallet_hash.wallet_note
    return res
  end

  def send_wallets
    elements = []
    wallets = get_wallets.result.last.data
    wallets.each do |wallet_hash|
      # {"wallet_id"=>62, "wallet_currency_id"=>1, "wallet_type_id"=>1, "wallet_category_id"=>2, "wallet_name"=>nil, "wallet_note"=>nil, "wallet_active"=>1, "wallet_balance"=>"6.00", "created_at"=>"2017-06-29 10:24:12", "updated_at"=>"2017-06-29 12:48:42", "deleted_at"=>nil, "wallet_user_id"=>"425", "wallet_primary"=>0}
      wallet_id = wallet_hash.wallet_id
      currency = get_currency(wallet_hash.wallet_currency_id)
      
      buttons = []
      
      buttons << {
        title: "Transfer",
        type: "postback",
        payload: "wallet_transfer:#{wallet_id}"
      }
      buttons << {
        title: "Add money",
        type: "postback",
        payload: "add_money:#{wallet_id}"
      }
      buttons << {
        title: "More actions",
        type: "postback",
        payload: "more_wallet_actions:#{wallet_id}"
      }
      elements << {
        title: wallet_title(wallet_hash),
        subtitle: wallet_subtitle(wallet_hash),
        buttons: buttons
      }
    end
    send_generic(elements)
  end

  def send_generic(elements)
    puts elements
    this_times = (elements.count/10.0).ceil
    this_times.times do |i|
      send_message(
        "attachment": 
        {
          "type": "template",
          "payload": {
            "template_type": "generic",
            "elements": elements[i*10..(i*10)+9]
          }
        })
    end
  end

  SSO_URL = "https://v1-sso-api.digitaltown.com/oauth/authorize?client_id=#{ENV['DT_CLIENT_ID']}&redirect_uri=#{ENV['HOST']}/incoming_digitaltown&response_type=code&scope=home_country"
  # STATE = {0 => "ask_for_role", 1 => "ask_for_business", 2 => "ask_for_location", }
  # STATES = [ask_for_lang, ask_for_role, send_welcome_message, ask_for_business, ]
  def on_postback(postback)
    payload = postback.payload
    message = postback
    if payload == "continue_customer"
      update_attributes(role: "customer", state: "state_ask_for_login")
      postback.reply(text: I18n.t('signed_up_as_customer'))
      # ask_for_location(message)
      ask_for_login
    elsif payload == "continue_business_owner"
      update_attributes(role: "business", state: "state_ask_for_login")
      postback.reply(text: I18n.t('signed_up_as_business'))
      ask_for_login
      # ask_for_business(message)
    # end
    elsif payload == "more_settings"
      send_more_settings(message)
    elsif payload == "GET_STARTED_PAYLOAD"
      send_select_language(message)
    elsif payload == "view_wallets"
      send_wallets
    elsif payload == "set_hindi"
      update_attributes(lang: "hi", state: "state_send_welcome_message")
      send_welcome_message(message)
    elsif payload == "set_english"
      update_attributes(lang: "en", state: "state_send_welcome_message")
      send_welcome_message(message)
    elsif payload == "update_location"
      ask_for_location(postback)  
    elsif payload == "disable_delivery"
      update_attribute(:delivery, false)
      message.reply(text: I18n.t('disable_delivery_success'))
    elsif payload == "update_name"
      message.reply(text: I18n.t('update_name'))
      update_attributes(state: "state_get_name")
    elsif payload == "update_phone"
      message.reply(text: I18n.t('update_phone'))
      update_attributes(state: "state_get_phone")
    elsif payload.include?("view_order")
      Order.view_order(message)
    elsif payload == "change_role"
      send_welcome_message(message)
    elsif payload == "update_grocery"
      ask_for_business(message)
    elsif payload == "enable_delivery"
      update_attribute(:delivery, true)
      send_delivery_success(message)
    elsif payload.include?("list_categories")
      send_select_list_categories(postback, payload.split(":").last.to_i)
    elsif payload.include?("remove_grocery")
      grocery_id = payload.split(":").last
      a = UserGroceryMapping.where(user_id: self.id, grocery_id: grocery_id)
      a.delete_all
      message.reply(text: "#{Grocery.find(grocery_id).name} " + I18n.t("removed"))
      update_attribute(:state, "state_done")
    elsif payload.include?("select_grocery")
      grocery_id = payload.split(":").last
      UserGroceryMapping.create(user_id: self.id, grocery_id: grocery_id)
      message.reply(text: "#{Grocery.find(grocery_id).name} " + I18n.t("added"))
      update_attribute(:state, "state_done")
    elsif payload.include?("order_from_store_item")
      store_id = payload.split(":").last
      item_id = payload.split(":")[-2]
      order = self.orders.create(item_ids: [item_id], store_id: store_id)
      message.reply(text: I18n.t("add_more_item", name: User.find(store_id).display_name), quick_replies: [
        {
          title: I18n.t("yes"),
          content_type: "text",
          payload: "order_from_store:#{order.id}:#{store_id}"
        },{
          title: I18n.t("no"),
          content_type: "text",
          payload: "place_order:#{order.id}"
        }
      ])
    elsif payload.include?("place_order")
      order_id = payload.split(":").last
      order = Order.find(order_id)
      order.place(message)
    elsif payload.include?("add_to_order_item")
      order_id = payload.split(":").last
      item_id = payload.split(":")[-2]
      order = self.orders.find(order_id)
      order.add_item(item_id)
    elsif payload.include?("search_stores")
      Grocery.send_stores(message, self)
    elsif payload.include?("set_delivery_distance")
      distance = payload.split(":").last
      update_attribute(:delivery_distance, distance)
      message.reply(text: I18n.t('delivery_distance_success', distance: distance))
    elsif payload.include?("book_cab")
      driver_id = payload.split(":").last
      #todo craete this function
      # book_cab(driver_id)
    elsif payload.include?("selected_category")
      order_id = payload.split(":").last
      category_id = payload.split(":")[-2]
      send_items_to_user(message, order_id, category_id)
    elsif payload.include?("view_wallets")
      send_wallets
    elsif payload.include?("update_wallet")
      wallet_id = payload.split(":").last
      # send_update_wallet
    elsif payload.include?("delete_wallet")
      wallet_id = payload.split(":").last
      delete_wallet(wallet_id)
      send_message(text: "Wallet deleted")
    elsif payload.include?("activate_wallet")
      wallet_id = payload.split(":").last
      activate_wallet(wallet_id)
      send_message(text: "Wallet activated")
    elsif payload.include?("deactivate_wallet")
      wallet_id = payload.split(":").last
      deactivate_wallet(wallet_id)
      send_message(text: "Wallet deactivated")
    elsif payload.include?("wallet_transfer")
      wallet_id = payload.split(":").last
      send_message(text: "Enter wallet id and amount space seperated \nExample: 65 12.50")
      update_attributes(state: "state_get_transfer_details", wallet_from: wallet_id)
    elsif payload.include?("select_type_of_profession")
      prof_index = payload.split(":").last
      if role == "business"
        update_attributes(profession: prof_index, state: "state_get_phone")
        send_message(text: "Your profession has been updated. Please send us your phone number so you clients can reach out to you")
      else
        Business.send_nearby_professional(self, prof_index)
      end
    elsif payload.include?("select_type_of_home_service")
      prof_index = payload.split(":").last
      if role == "business"
        update_attributes(home_service: prof_index, state: "state_get_phone")
        send_message(text: "Your profession has been updated. Please send us your phone number so you clients can reach out to you")
      else
        Business.send_nearby_home_services(self, prof_index)
      end
    elsif payload.include?("set_type_of_business")
      business_id = payload.split(":").last
      update_attributes(type_of_business: business_id)
      Business.ask_for_business_details(self)
    elsif payload.include?("add_money")
      wallet_id = payload.split(":").last
      send_message(text: "Enter amount  \nExample: 12.50")
      update_attributes(state: "state_add_money_details", wallet_from: wallet_id)
      # super hack
    elsif payload.include?("more_wallet_actions")
      wallet_id = payload.split(":").last
      send_more_actions_wallet(wallet_id)
    end
  end

  def send_items_to_user(message, order_id, category_id)
    category = Grocery.find(category_id)
    message.reply(text: I18n.t("more_items_from_store_in_category", category: category.name))
    Grocery.send_store_items(message, category.children, order_id)
  end

  def send_categories_to_user(message, order_id)
    current_store_categories = groceries.top_categories
    message.reply(text: I18n.t("more_items_from_store_select_category", name: display_name))
    Grocery.send_store_categories(message, current_store_categories, order_id)
  end

  def name
    return "#{first_name} #{last_name}"
  end

  def send_delivery_success(message)
    delivery_distances = I18n.t('delivery_distances')
    quick_replies = []
    delivery_distances.each do |item|
      quick_replies << {
        content_type: 'text',
        title: item,
        payload: "set_delivery_distance:#{item}"
      }
    end
    quick_replies << {
      content_type: 'text',
      title: "Anywhere in city",
      payload: "set_delivery_distance:any"
    }
    message.reply(text: I18n.t('enable_delivery_success'))
    message.reply(
        text: I18n.t('select_delivery_distance'),
        quick_replies: quick_replies
      )
  end

  def send_message(message)
    payload = {
            recipient: {id: fb_id},
            message: message
    }
    Facebook::Messenger::Bot.deliver(payload, access_token: ENV['ACCESS_TOKEN'])
  end

  def send_more_settings(message)
    if role == "business"
      delivery_key = self.delivery ? "disable_delivery" : "enable_delivery"
      send_buttons(message, I18n.t("more_settings"), 
        { 
          "update_name" => I18n.t("update_name_menu"),
          "update_phone" => I18n.t("update_phone_menu"),
          "update_grocery" => I18n.t("update_grocery"),
        }
      )
      send_buttons(message, "more options..", 
        { 
          delivery_key => I18n.t(delivery_key)
        }
      )
    else
      send_buttons(message, I18n.t("more_settings"), 
        { 
          "new_order" => I18n.t("new_order"),
          "view_past_orders" => I18n.t("view_past_orders")
        }
      )
    end
  end

  def handle_quick_replies(message)
    payload = message.quick_reply
    if payload.include?("set_delivery_distance")
      distance = payload.split(":").last
      update_attribute(:delivery_distance, distance)
      message.reply(text: I18n.t('delivery_distance_success', distance: distance))
    elsif payload.include?("order_from_store")
      store_id = payload.split(":").last
      order_id = payload.split(":")[-2]
      u = User.find(store_id)
      u.send_categories_to_user(message, order_id)
    elsif payload.include?("place_order")
      order_id = payload.split(":").last
      order = Order.find(order_id)
      order.place(message)
    elsif payload.include?("money_from")
      to = payload.split(":")[-2]
      from = payload.split(":")[-3]
      amount = payload.split(":")[-1]
      User.send_money(from, to, amount)
    elsif payload.include?("declined_money")
      user_id = payload.split(":").last
      user = User.find user_id
      user.send_message(text: "#{name} declined transaction")
    end
  end

  def business?
    role == "business"
  end

  def start_flow(message)
    if !message.location_coordinates.blank?
      message.reply(text: I18n.t("location_updated"))
      update_attribute(:latlong, message.location_coordinates)
      # message.reply(text: I18n.t("enter_search"))
      
      return
    end
    if !message.quick_reply.blank?
      handle_quick_replies(message)
      puts "wo"
      return
    end
    if message.text.to_s.downcase.include?("update location")
      ask_for_location
    end
    if message.text.to_s.downcase.include?("send money")
      #todo
      send_message(text: "Please enter email address of user you want to sent money to and amuont space seperated\nExample: mohmun16@gmail.com 10")
      update_attributes(state: "state_send_money")
      return
    end
    if message.text.to_s.downcase.include?("receive money")
      #todo
      send_message(text: "Please enter email address of user you want to receive money from and amuont space seperated\nExample: mohmun16@gmail.com 10")
      update_attributes(state: "state_receive_money")
      return
    end
    if self.state.blank?
      self.state = "state_ask_for_lang"
    end
    case self.state
    when "state_ask_for_lang"
      send_select_language(message)
    when "state_send_welcome_message"
      send_welcome_message(message)
    when "state_ask_for_business"
      Business.ask_for_business(self, message)
    when "state_get_house_details"
      update_attributes(house_details: message.text, state: "state_done")
      ask_for_location
    when "state_get_house_img"
      res = []
      message.attachments.each do |a|
        res << a.payload.url
      end
      update_attributes(house_images: res[0], state: "state_get_house_details")
      send_message(text: "Please tell more info about your apartment like number of rooms, amenities etc")
    when "state_get_car_details"
      update_attributes(car_details: message.text, state: "state_done")
      send_message(text: "Car details has been updated! You can now update your location from menu or simple type update location for getting nearby customers")
      ask_for_location
    when "state_get_car_no"
      update_attributes(car_no: message.text, state: "state_get_car_details")
      send_message(text: "Your car number is updated! Please give us brief discription about you car. It will help customers finding one")
    when "state_send_money"
      email,amount = message.text.split(" ") rescue [nil,nil]
      if !email.blank? && !amount.blank?
        user = User.find_by_email(email) rescue nil
        if user.blank?
          send_message(text: "User not found")
        else
          User.send_money(self.id, user.id, amount)
        end
      end
      state_done
    when "state_receive_money"
      email,amount = message.text.split(" ") rescue [nil,nil]
      if !email.blank? && !amount.blank?
        user = User.find_by_email(email)
        user.send_message(text: "#{name} is requesting #{amount} money from you. Do you want to continue?", quick_replies: [
        {
          title: I18n.t("yes"),
          content_type: "text",
          payload: "money_from:#{user.id}:#{self.id}:#{amount}"
        },{
          title: I18n.t("no"),
          content_type: "text",
          payload: "declined_money:#{self.id}"
        }
      ])
      end
      state_done
    when "state_get_name"
      update_attributes(display_name: message.text, state: "state_done")
      message.reply(text: I18n.t("update_name_success", name: message.text))
    when "state_get_phone"
      update_attributes(phone: message.text, state: "state_done")
      message.reply(text: I18n.t("update_phone_success", phone: message.text))
    when "state_done"
      after_onboarding(message)
    when "state_get_transfer_details"
      to_id, amount = message.text.split(" ")
      wallet_transfer(wallet_from, to_id, amount)
      send_message(text: "Money transferred!")
      update_attributes(state: "state_done")
      send_wallets
    when "state_ask_for_order"
      # query = message.text
      if message.text.size > 2
        message.reply(text: I18n.t("searching_for", query: message.text))
        Grocery.send_items(message)
      else
        message.reply(text: I18n.t("enter_minimum_3", query: message.text))
      end
      update_attributes(state: "state_done")
    else
      send_select_language(message)
      # send_welcome_message(message)
    end
  end

  def state_done
    update_attributes(state: "state_done")
  end

  def ask_for_groceries
    # Grocery.send_select_list(message, 1)
    send_message(text: I18n.t("select_grocery"))
    send_select_list_categories(nil, 0)
  end

  def after_onboarding(message)
    # message.reply(text: "Onboarded")
    # send_more_settings(message)
    Business.ask_for_business(self)
  end

  def self.send_money(from, to, amount)
    from_user = User.find(from)
    to_user = User.find(to)
    from_walllet_id = from_user.get_wallets.result.last.data.last.wallet_id
    to_walllet_id = to_user.get_wallets.result.last.data.last.wallet_id
    from_user.wallet_transfer(from_walllet_id, to_walllet_id, amount)
    from_user.send_message(text: "Transaction complete! You have sent #{amount} to #{to_user.name}")
    to_user.send_message(text: "Transaction complete! You have received #{amount} from #{from_user.name}")
    from_user.send_wallets
    to_user.send_wallets
  end

  def send_select_list_categories(message, page)
    elements = []
    buttons = []
    if(Grocery.top_categories.count - Grocery::COUNT*page > 0)
      buttons << {
        "title": "View More(#{(page+1)*Grocery::COUNT}/#{Grocery.top_categories.count})",
        "type": "postback",
        "payload": "list_categories:#{page+1}"
      }
    end
    # buttons << {
    #   title: "Chus",type: "postback", payload: "chus"
    # }
    Grocery.top_categories.offset(Grocery::COUNT*page).limit(Grocery::COUNT).each do |item|
      payload = "select_grocery:#{item.id}"
      title = I18n.t('select') + " #{item.name}"
      if groceries.pluck(:id).include?(item.id)
        title = I18n.t('remove') + " #{item.name}"
        payload = "remove_grocery:#{item.id}"
      end
      element_buttons = [
          {
            "title": title,
            "type": "postback",
            "payload": payload
          }
          # ,
          # {
          #   "title": I18n.t('remove'),
          #   "type": "postback",
          #   "payload": "remove_grocery:#{item.id}"
          # },
          # {
          #   "title": I18n.t('show_items'),
          #   "type": "postback",
          #   "payload": "show_items_grocery:#{item.id}"
          # }
        
        ]
      element = {
        "title": item.name,
        "subtitle": item.children.map(&:name).join(","),
        "buttons": element_buttons
      }
      elements << element
    end
    if !elements.blank?
      send_list(elements, buttons)
    end
  end

  def send_generic(elements)
    this_times = (elements.count/10.0).ceil
    this_times.times do |i|
      send_message(
        "attachment": 
        {
          "type": "template",
          "payload": {
            "template_type": "generic",
            "elements": elements[i*10..(i*10)+9]
          }
        })
    end
  end

  def ask_for_location(message = nil)
    send_message("text": "Please share your location:",
        "quick_replies":[
          {
            "content_type": "location",
          }
        ])
  end

end
