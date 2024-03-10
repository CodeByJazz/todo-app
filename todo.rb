require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do 
  enable :sessions 
  set :session_secret, SecureRandom.hex(32)
  set :erb, :escape_html => true
end

before do 
  session[:lists] ||= []
end

get "/" do 
  redirect "/lists"
end

helpers do 
  def list_complete?(list)
    todos_count(list) > 0 && remaining_todos_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_count(list)
    list[:todos].size
  end

  def remaining_todos_count(list)
    list[:todos].count { |todo| todo[:completed] == false }
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end

# View all of the lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do 
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid. Return nil if name is valid
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Redirect user if the list doesn't exist. 
def invalid_list(list)
  if list.nil?
    session[:error] = "The specified list was not found."
    redirect "/"
  end
end

# Return an error message if the name is invalid. Return nil if name is valid 
def error_for_todo(name)
  if !(1..100).cover? name.size
    "Todo must be between 1 and 100 characters."
  end
end

def next_list_id(lists) 
  max = lists.map { |list| list[:id] }.max || 0
  max + 1
end

# Create a new list
post "/lists" do 
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error 
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_list_id(session[:lists])
    session[:lists] << {id: id, name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# View list page 
get "/lists/:id" do 
  @index = params[:id].to_i
  @list = session[:lists].find { |list| list[:id] == @index }

  invalid_list(@list)
  erb :list, layout: :layout 
end

# Edit existing todo list
get "/lists/:id/edit" do 
  @index = params[:id].to_i
  @list = session[:lists].find { |list| list[:id] == @index }
  erb :edit_list, layout: :layout
end

# Change list name 
post "/lists/:id/edit" do 
  @index = params[:id].to_i
  @list = session[:lists].find { |list| list[:id] == @index }
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{@index}"
  end
end

# Delete List
post "/lists/:id/delete" do 
  @index = params[:id].to_i
  session[:lists].delete_if { |list| list[:id] == @index }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

def next_todo_id(todos)
  max = todos.map { |todo| todo[:id] }.max || 0
  max + 1
end

# Add a new todo to a list
post "/lists/:id/todos" do 
  @index = params[:id].to_i
  @list = session[:lists].find { |list| list[:id] == @index }
  todo = params[:todo].strip
  error = error_for_todo(todo)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_todo_id(@list[:todos])
    @list[:todos] << { id: id, name: todo, completed: false }


    session[:success] = "The todo was added."
    redirect "/lists/#{@index}"
  end
end

post "/lists/:id/todos/:todo_id/delete" do 
  @index = params[:id].to_i
  @list = session[:lists].find { |list| list[:id] == @index }
  @todo_index = params[:todo_id].to_i

  @list[:todos].delete_if {|todo| todo[:id] == @todo_index}

  if env["HTTP_X_REQUESTED_WITH"] === "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@index}"
  end
end

# Update the status of a todo
post "/lists/:id/todos/:todo_id" do 
  @index = params[:id].to_i
  @list = session[:lists].find { |list| list[:id] == @index }

  @todo_index = params[:todo_id].to_i
  is_completed = params[:completed] == "true"
  todo = @list[:todos].find { |todo| todo[:id] == @todo_index}
  todo[:completed] = is_completed

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@index}"
end

# Mark all todos in list complete 
post "/lists/:id/complete_all" do 
  @index = params[:id].to_i
  @list = session[:lists].find { |list| list[:id] == @index }

  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All todos have been completed."
  redirect "/lists/#{@index}"
end
