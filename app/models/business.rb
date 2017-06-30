class Business
  TYPE_OF_BUSINESS = [
{"customer_title" => "I want to book a cab",  "id" => "uberkiller", "subtitle" => "uberkiller", "title" => "I'm taxi driver"}, 
{"customer_title" => "I want take house on rent",  "id" => "airbnbkiller", "subtitle" => "airbnbkiller", "title" => "I want to rent my house"}, 
{"customer_title" => "I want professional services",  "id" => "professional_services", "subtitle" => "professional_services", "title" => "I provide professional services"}, 
{"customer_title" => "I want home services",  "id" => "housejoykiller", "subtitle" => "housejoykiller", "title" => "I provide Home services"}, 
{"customer_title" => "I want some groceries and household items",  "id" => "store", "subtitle" => "store", "title" => "I own a store"}
]
  
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

  def self.ask_for_business_details(user)
    case user.type_of_business
    when "store"
      user.ask_for_groceries
    when "uberkiller"
      user.send_message(text: "What is your car license number")
      user.update_attributes(state: "state_get_car_no")
    when "airbnbkiller"
      user.send_message(text: "Please send images of your house")
      user.update_attributes(state: "state_get_house_img")
    when "professional_services"
      send_prof_list(user)
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

  def self.send_nearby_professional(user, prof_index)
    user.send_message(text: "Sending nearby #{Business::TYPE_OF_PROFFESSIONS[prof_index]}")
  end
end