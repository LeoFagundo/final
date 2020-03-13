# Set up for the application and database. DO NOT CHANGE. #############################
require "sequel"                                                                      #
connection_string = ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/development.sqlite3"  #
DB = Sequel.connect(connection_string)                                                #
#######################################################################################

# Database schema - this should reflect your domain model
DB.create_table! :coffee do
  primary_key :id
  String :shop_name
  String :location
end
DB.create_table! :reviews do
  primary_key :id
  foreign_key :coffee_id
  foreign_key :users_id
  Integer :rating
  String :comments, text: true
  String :date
end

DB.create_table! :users do
  primary_key :id
  String :name
  String :email
  String :password
end

# Insert initial (seed) data
coffee_table = DB.from(:coffee)

coffee_table.insert(shop_name: "Newport Coffee", 
                    location: "Evanston, IL")

coffee_table.insert(shop_name: "Mojo Coffeehouse", 
                    location: "New Orleans, LA")
puts "success"
