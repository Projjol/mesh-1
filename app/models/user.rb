class User < ActiveRecord::Base
  store_accessor :json_store, :profile_pic, :state, :lang, :latlong, :delivery, :delivery_distance, :display_name, :phone
  has_and_belongs_to_many :groceries, join_table: "user_grocery_mappings"
  has_many :orders
  def self.create_from_message(message)
    user = User.create(fb_id: message.sender['id'], state: "state_ask_for_lang")
    user.save_fb_profile
    # user.send_welcome_message(message)
    user.send_select_language(message)
  end

  after_initialize :init

  def init
    self.latlong = [0,0] if !latlong.blank?
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
  # STATE = {0 => "ask_for_role", 1 => "ask_for_business", 2 => "ask_for_location", }
  # STATES = [ask_for_lang, ask_for_role, send_welcome_message, ask_for_business, ]
  def on_postback(postback)
    payload = postback.payload
    message = postback
    if payload == "continue_customer"
      update_attributes(role: "customer", state: "state_ask_for_order")
      postback.reply(text: I18n.t('signed_up_as_customer'))
      ask_for_location(message)
    elsif payload == "continue_business_owner"
      update_attributes(role: "business", state: "state_ask_for_business")
      postback.reply(text: I18n.t('signed_up_as_business'))
      ask_for_business(message)
    # end
    elsif payload == "more_settings"
      send_more_settings(message)
    elsif payload == "GET_STARTED_PAYLOAD"
      send_select_language(message)
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
    elsif payload.include?("selected_category")
      order_id = payload.split(":").last
      category_id = payload.split(":")[-2]
      send_items_to_user(message, order_id, category_id)
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
    end
  end

  def start_flow(message)
    if !message.location_coordinates.blank?
      message.reply(text: I18n.t("location_updated"))
      update_attribute(:latlong, message.location_coordinates)
      message.reply(text: I18n.t("enter_search"))
      return
    end
    if !message.quick_reply.blank?
      handle_quick_replies(message)
      puts "wo"
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
      ask_for_business(message)
    when "state_get_name"
      update_attributes(display_name: message.text, state: "state_done")
      message.reply(text: I18n.t("update_name_success", name: message.text))
    when "state_get_phone"
      update_attributes(phone: message.text, state: "state_done")
      message.reply(text: I18n.t("update_phone_success", phone: message.text))
    when "state_done"
      after_onboarding(message)
    when "state_ask_for_order"
      # query = message.text
      if message.text.size > 2
        message.reply(text: I18n.t("searching_for", query: message.text))
        Grocery.send_items(message)
      else
        message.reply(text: I18n.t("enter_minimum_3", query: message.text))
      end
    else
      send_select_language(message)
      # send_welcome_message(message)
    end
  end

  def ask_for_business(message)
    # Grocery.send_select_list(message, 1)
    message.reply(text: I18n.t("select_grocery"))
    send_select_list_categories(message, 0)
  end

  def after_onboarding(message)
    # message.reply(text: "Onboarded")
    send_more_settings(message)
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
      User.send_list(message, elements, buttons)
    end
  end

  def ask_for_location(message)
    message.reply("text": "Please share your location:",
        "quick_replies":[
          {
            "content_type": "location",
          }
        ])
  end

end
