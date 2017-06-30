class Business
  TYPE_OF_BUSINESS = [
{"customer_title" => "I want to book a cab",  "id" => "uberkiller", "subtitle" => "uberkiller", "title" => "I'm taxi driver"}, 
{"customer_title" => "I want take house on rent",  "id" => "airbnbkiller", "subtitle" => "airbnbkiller", "title" => "I want to rent my house"}, 
{"customer_title" => "I want professional services",  "id" => "professional_services", "subtitle" => "professional_services", "title" => "I provide professional services"}, 
{"customer_title" => "I want home services",  "id" => "housejoykiller", "subtitle" => "housejoykiller", "title" => "I provide Home services"}, 
{"customer_title" => "I want some groceries and household items",  "id" => "store", "subtitle" => "store", "title" => "I own a store"}
]
  TYPE_OF_HOME_SERVICES = ["Home Cleaning", "Pest Control", "Appliances", "Plumbing", "Electrical", "Carpentry", "Laundry", "Cars & Bikes", "Computer Repair", "Painting", "Movers and Packers"]
  TYPE_OF_PROFFESSIONS = ["Accountant", "Actuary", "Architect", "Dentist", "Engineer", "Evaluator", "Financial Planner", "Investment manager", "IT consultant", "Lawyer", "Management consultant", "Pharmacist", "Physician", "Registered nurse"]

  def self.ask_for_business(user)
    # Grocery.send_select_list(message, 1)
    # message.reply(text: I18n.t("select_business"))
    elements = []
    TYPE_OF_BUSINESS.each do |hash|
      title = hash.title
      if user.role == "customer"
        title = hash.customer_title
      end
      element_buttons = [
          {
            "title": "Select",
            "type": "postback",
            "payload": "set_type_of_business:#{hash.id}"
          }
        ]
      element = {
        "title": title,
        "subtitle": hash.subtitle,
        "buttons": element_buttons
      }
      elements << element
    end
    user.send_list(elements, [])
  end

  def self.drivers
    User.drivers
  end

  def self.ask_for_business_details(user)
    case user.type_of_business
    when "store"
      if user.business?
        user.ask_for_groceries
      else
        user.send_message(text: I18n.t("enter_search"))
        user.update_attributes(state: "state_ask_for_order")
      end
    when "uberkiller"
      if user.business?
        user.send_message(text: "What is your car license number")
        user.update_attributes(state: "state_get_car_no")
      else
        send_nearby_drivers(user)
      end
    when "airbnbkiller"
      if user.business?
        user.send_message(text: "Please send images of your house")
        user.update_attributes(state: "state_get_house_img")
      else
        send_nearby_apartments(user)
      end
    when "professional_services"
      send_prof_list(user)
    when "housejoykiller"
      send_home_services_list(user)
    end
    
  end

  def self.send_nearby_drivers(user)
    elements = []
    User.drivers.each do |driver|
      buttons = []
      distance = Grocery.cal_distance(driver.latlong, user.latlong)/1000.0 rescue 0.0
      distance = distance.round(2)
      buttons << {
        title: I18n.t("call"),
        type: "phone_number",
        payload: driver.phone
      }
      buttons << {
        title: "Book cab",
        type: "postback",
        payload: "book_cab:#{driver.id}"
      }
      elements << {
        title: "Driver name: #{driver.name}",
        subtitle: "#{distance}km - #{driver.car_no} - #{driver.car_details}",
        buttons: buttons
      }
    end
    if elements.blank?
      user.send_message(text: "No drivers")
    else
      user.send_message(text: "Total #{elements.count} cabs found nearby")
      user.send_generic(elements)
    end
  end

  def self.send_nearby_apartments(user)
    elements = []
    User.airbnbkillers.each do |driver|
      buttons = []
      distance = Grocery.cal_distance(driver.latlong, user.latlong)/1000.0 rescue 0.0
      distance = distance.round(2)
      buttons << {
        title: I18n.t("call"),
        type: "phone_number",
        payload: driver.phone
      }
      elements << {
        title: "Owner name: #{driver.name}",
        image_url: driver.house_images,
        subtitle: "#{distance}km - #{driver.house_details}",
        buttons: buttons
      }
    end
    if elements.blank?
      user.send_message(text: "No house")
    else
      user.send_message(text: "Total #{elements.count} house found nearby")
      user.send_generic(elements)
    end
  end

  def self.send_prof_list(user)
    elements = []
    TYPE_OF_PROFFESSIONS.each_with_index do |name, index|
      element_buttons = [
          {
            "title": "Select",
            "type": "postback",
            "payload": "select_type_of_profession:#{index}"
          }
        ]
      element = {
        "title": name,
        "subtitle": "",
        "buttons": element_buttons
      }
      elements << element
    end
    user.send_list(elements, [])
  end

  def self.send_home_services_list(user)
    elements = []
    TYPE_OF_HOME_SERVICES.each_with_index do |name, index|
      element_buttons = [
          {
            "title": "Select",
            "type": "postback",
            "payload": "select_type_of_home_service:#{index}"
          }
        ]
      element = {
        "title": name,
        "subtitle": "",
        "buttons": element_buttons
      }
      elements << element
    end
    user.send_list(elements, [])
  end

  def self.send_nearby_professional(user, prof_index)
    prof_index = prof_index.to_i
    profession_name = Business::TYPE_OF_PROFFESSIONS[prof_index]
    user.send_message(text: "Sending details of nearby #{Business::TYPE_OF_PROFFESSIONS[prof_index]}")
    elements = []
    User.professional_services.where("(json_store ->> 'profession') = ?", prof_index.to_s).each do |driver|
      buttons = []
      distance = Grocery.cal_distance(driver.latlong, user.latlong)/1000.0 rescue 0.0
      distance = distance.round(2)
      buttons << {
        title: I18n.t("call"),
        type: "phone_number",
        payload: driver.phone
      }
      elements << {
        title: "Name: #{driver.name}",
        subtitle: "#{distance}km - #{profession_name}",
        buttons: buttons
      }
    end
    if elements.blank?
      user.send_message(text: "No result")
    else
      user.send_message(text: "Total #{elements.count} results")
      user.send_generic(elements)
    end
  end

  def self.send_nearby_home_services(user, prof_index)
    prof_index = prof_index.to_i
    user.send_message(text: "Sending details of nearby #{Business::TYPE_OF_HOME_SERVICES[prof_index]}")
    
  end

  def self.create_cabs
    10.times do |i|
      name = "Cab #{i}"
      cols = ["Green", "Red", "Yellow"]
      cars = ["Acura","Alfa Romeo","Aston Martin","Audi","Bentley","BMW","Bugatti","Buick"]
      car_details = cols.sample + " " + cars.sample
      json = {
          "first_name": name,
          "last_name": "",
          "json_store": {
            "state": "state_done",
            "lang": "en",
            "latlong": [Random.rand(90), Random.rand(180)],
            "display_name": name,
            "car_no": "MH #{Random.rand(9999) }",
            "car_details": car_details,
            "type_of_business": "uberkiller",
            "phone": "#{Random.rand(10**10)}",
          },
          "role": "business",
          "fb_id": "A144697749532#{Random.rand(1000)}"
          }
      User.create(json)
    end
  end

  def self.create_prof
    20.times do |i|
      profession = Random.rand(TYPE_OF_PROFFESSIONS.count)
      name = "#{TYPE_OF_PROFFESSIONS[profession]} #{i}"
      
      json = {
          "first_name": name,
          "last_name": "",
          "json_store": {
            "state": "state_done",
            "lang": "en",
            "latlong": [Random.rand(90), Random.rand(180)],
            "display_name": name,
            "profession": profession,
            "type_of_business": "professional_services",
            "phone": "#{Random.rand(10**10)}",
          },
          "role": "business",
          "fb_id": "A144697749532#{Random.rand(1000)}"
          }
      User.create(json)
    end
  end

 def self.create_home
    20.times do |i|
      profession = Random.rand(TYPE_OF_HOME_SERVICES.count)
      name = "#{TYPE_OF_HOME_SERVICES[profession]} #{i}"
      
      json = {
          "first_name": name,
          "last_name": "",
          "json_store": {
            "state": "state_done",
            "lang": "en",
            "latlong": [Random.rand(90), Random.rand(180)],
            "display_name": name,
            "home_service": profession,
            "type_of_business": "housejoykiller",
            "phone": "#{Random.rand(10**10)}",
          },
          "role": "business",
          "fb_id": "A144697749532#{Random.rand(1000)}"
          }
      User.create(json)
    end
  end


  def self.create_bnbs
    10.times do |i|
      name = "House #{i}"
      urls = ["http://media.equityapartments.com/images/c_crop,x_0,y_0,w_1920,h_1080/c_fill,w_1920,h_1080/q_80/3198-5/the-west-end-apartments-asteria-building.jpg", "https://ph4na3zvw62si4xh30sk636e-wpengine.netdna-ssl.com/wp-content/uploads/2015/06/apartments-tucson.jpg",
      "http://encantadaliving.com/riverside-crossing/wp-content/uploads/sites/4/2015/05/Riverside-04.jpg",
    "http://www.arizonafoothillsmagazine.com/images/stories/july13/kitchen.jpg",
  "https://s-media-cache-ak0.pinimg.com/originals/93/f5/6e/93f56e47233e852909b126a5587b6457.jpg"]
      bhk = ["4BHK", "Bunglow", "27th Floor - 5BHK - Hill view"]
      ame = ["Swimming pool", "Gym", "Parking"]
      car_details = bhk.sample + " - " + ame.sample
      json = {
          "first_name": name,
          "last_name": "",
          "json_store": {
            "state": "state_done",
            "lang": "en",
            "latlong": [Random.rand(90), Random.rand(180)],
            "display_name": name,
            "house_images": urls.sample,
            "house_details": car_details,
            "type_of_business": "airbnbkiller",
            "phone": "#{Random.rand(10**10)}",
          },
          "role": "business",
          "fb_id": "A144697749532#{Random.rand(1000)}"
          }
      User.create(json)
    end
  end

end