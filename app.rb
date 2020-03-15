# Set up for the application and database. DO NOT CHANGE. #############################
require "sinatra"                                                                     #
require "sinatra/reloader" if development?                                            #
require "sequel"                                                                      #
require "logger"                                                                      #
require "twilio-ruby"                                                                 #
require "bcrypt"                                                                      #
connection_string = ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/development.sqlite3"  #
DB ||= Sequel.connect(connection_string)                                              #
DB.loggers << Logger.new($stdout) unless DB.loggers.size > 0                          #
def view(template); erb template.to_sym; end                                          #
use Rack::Session::Cookie, key: 'rack.session', path: '/', secret: 'secret'           #
before { puts; puts "--------------- NEW REQUEST ---------------"; puts }             #
after { puts; }                                                                       #
#######################################################################################

coffee_table = DB.from(:coffee)
reviews_table = DB.from(:reviews)
users_table = DB.from(:users)

before do
    @current_user = users_table.where(id: session["users_id"]).to_a[0]
end

# homepage and list of events (aka "index")
get "/" do
    puts "params: #{params}"

    @coffee = coffee_table.all.to_a
    pp @coffee

    view "coffee"
end

# coffee details (aka "show")
get "/coffee/:id" do
    puts "params: #{params}"

    @users_table = users_table
    @coffee = coffee_table.where(id: params[:id]).to_a[0]
    pp @coffee

    @reviews = reviews_table.where(coffee_id: @coffee[:id]).to_a
    @avg_rating = reviews_table.where(coffee_id: @coffee[:id]).avg(:rating)

    view "coffee_shop"
end

# display the review form 
get "/coffee/:id/reviews/new" do
    puts "params: #{params}"

    @coffee = coffee_table.where(id: params[:id]).to_a[0]
    view "new_review"
end

# receive the submitted rsvp form (aka "create")
post "/coffee/:id/reviews/create" do
    puts "params: #{params}"

    # first find the coffee that rsvp'ing for
    @coffee = coffee_table.where(id: params[:id]).to_a[0]
    # next we want to insert a row in the rsvps table with the rsvp form data
    reviews_table.insert(
        coffee_id: @coffee[:id],
        users_id: session["users_id"],
        comments: params["comments"],
        rating: params["rating"]
    )

    redirect "/coffee/#{@coffee[:id]}"
end

# display the review form (aka "edit")
get "/reviews/:id/edit" do
    puts "params: #{params}"

    @reviews = reviews_table.where(id: params["id"]).to_a[0]
    @coffee = coffee_table.where(id: @reviews[:coffee_id]).to_a[0]
    view "edit_review"
end

# receive the submitted reviews form (aka "update")
post "/reviews/:id/update" do
    puts "params: #{params}"

    # find the reviews to update
    @reviews = reviews_table.where(id: params["id"]).to_a[0]
    # find the review's coffee shop
    @coffee = coffee_table.where(id: @reviews[:coffee_id]).to_a[0]
    #in case user bug lets them edit another review
    if @current_user && @current_user[:id] == @reviews[:id]
        reviews_table.where(id: params["id"]).update(
            rating: params["rating"],
            comments: params["comments"]
        )

        redirect "/coffee/#{@coffee[:id]}"
    else
        view "error"
    end
end

# delete the reviews (aka "destroy")
get "/reviews/:id/destroy" do
    puts "params: #{params}"

    @reviews = reviews_table.where(id: params["id"]).to_a[0]
    @coffee = coffee_table.where(id: @reviews[:coffee_id]).to_a[0]

    reviews_table.where(id: params["id"]).delete

    redirect "/coffee/#{@coffee[:id]}"
end

# display the signup form (aka "new")
get "/users/register" do
    view "register"
end

# receive the submitted signup form (aka "create")
post "/users/create" do
    puts "params: #{params}"

    # if there's already a user with this email, skip!
    existing_user = users_table.where(email: params["email"]).to_a[0]
    if existing_user
        view "error"
    else
        users_table.insert(
            name: params["name"],
            email: params["email"],
            password: BCrypt::Password.create(params["password"])
        )

        redirect "/logins/new"
    end
end

# display the login form (aka "new")
get "/logins/new" do
    view "new_login"
end

# receive the submitted login form (aka "create")
post "/logins/create" do
    puts "params: #{params}"

    # step 1: user with the params["email"] ?
    @users = users_table.where(email: params["email"]).to_a[0]

    if @users
        # step 2: if @user, does the encrypted password match?
        if BCrypt::Password.new(@users[:password]) == params["password"]
            # set encrypted cookie for logged in user
            session["users_id"] = @users[:id]
            redirect "/"
        else
            view "register_failed"
        end
    else
        view "register_failed"
    end
end

# logout user
get "/logout" do
    # remove encrypted cookie for logged out user
    session["users_id"] = nil
    redirect "/logins/new"
end