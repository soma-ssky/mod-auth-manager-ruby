require 'vertx'
require 'bcrypt'
require 'securerandom'
require 'json'

include Vertx
include BCrypt

p "INIT"
def parse body
  Hash[body[1...-1].split(', ').collect{|x| x.split(': ').collect{|y| y[1...-1]}}]
end
def parse2 body
  Hash[body[1...-1].split(', ').collect{|x| x.split('=>').collect{|y| y[1...-1]}}]
end

Server = HttpServer.new
RM = RouteMatcher.new
Mongo = "sven.mongo.persistor" #vertx runmod io.vertx~mod-mongo-persistor~2.0.0-final -cluster -conf mongo_conf.json 
EB = EventBus
TIME_OUT = 900000
Session = Hash.new
HTTP = Hash.new
HTTP[:OK] = 200
HTTP[:BAD_REQUEST] = 400
HTTP[:INTERNAL_SERVER_ERROR] = 500

def wrap_code code, content = nil
  if(content != nil)
    JSON.generate({"code" => HTTP[code], "body" => content})
  else
    JSON.generate({"code" => HTTP[code]})
  end
end

# type1 : https : Vertx::HttpServerRequest
# type2 : eb : Vertx::Message
def resp target, type, content 
  if type == 1
    target.end(content)
  elsif type == 2
    target.reply(content)
  end
end

def post_user_handler(body, target, type)
  enc_password = Password.create(body["password"])
  p "ASSERTION FAILURE !!!!!" unless enc_password == body["password"]
  EB.send(Mongo, {
    collection: 'users',
    action: 'save',
    document: {
      username: "#{body["username"]}",
      enc_password: "#{enc_password}"}
  }) do |message|
    if message.body["status"] #false
      my_json = JSON.generate({"username" => body["username"], "_id" => message.body["_id"]})
      resp(target, type, wrap_code(:OK, my_json))
    else
      resp(target, type, wrap_code(:INTERNAL_SERVER_ERROR))
    end
  end
end

def post_token_handler(body, target, type)
  EB.send(Mongo, {
    action: 'find',
    collection: 'users',
    matcher: {
      username: body["username"]
    }}) do |message|
      if message.body["status"] != "ok"
        resp(target, type, wrap_code(:INTERNAL_SERVER_ERROR))
      elsif message.body["number"] != 1
        resp(target, type, wrap_code(:INTERNAL_SERVER_ERROR, "There are multiple matched users."))
      else
        username = message.body["results"][0]["username"]
        enc_password = Password.new(message.body["results"][0]["enc_password"])
        if not (username == body["username"] and enc_password == body["password"])
          resp(target, type, wrap_code(:BAD_REQUEST, "Username or passord not valid."))
        else
          token = SecureRandom.hex
          expires_at = Time.now.to_i + TIME_OUT
          EB.send(Mongo, {
            action: 'update',
            collection: 'users',
            criteria: {username: body["username"]},
            objNew: {:"$set" => {token: token, expires_at: expires_at}}
          }) do |message2|
            my_json = JSON.generate({"token" => token})
            resp(target, type, wrap_code(:OK, my_json))
          end
        end
      end
#    my_json = JSON.generate({"action" => "update", "collection" => "users", "criteria" => {"username" => body["username"]}, "objNew" => {"$set" => {"expires_at" => expires_at}}})
  end
end

def check_token token
  EB.send(Mongo, {
    collection: 'users',
    action: 'find',
    matcher: {token: token}
  }) do |message|
    p "inside check_token"
#    p message
#    p message.body
    p "# of matched user : " + message.body["number"].to_s
    if not message.body["number"].zero?
      p message.body["results"][0]["token"]
      p message.body["results"][0]["expires_at"]
      p Time.now.to_i
    end
  end
end

def reset_handler
  EB.send(Mongo, {
    action: 'command',
    command: '{dropDatabase: 1}'
  }) do |message|
#    p message
  end
end

RM.get('/') do |req| 
  req.response.send_file "index.html" 
end
RM.post('/users') do |req|
  body = Buffer.create
  req.data_handler{|buffer| body.append_buffer(buffer)}
  req.end_handler do
    post_user_handler (parse body.to_s), req.response, 1
  end
end
RM.post('/tokens') do |req|
  body = Buffer.create
  req.data_handler{|buffer| body.append_buffer(buffer)}
  req.end_handler do
    post_token_handler (parse body.to_s), req.response, 1
  end
end
RM.get('/users/:uid') do |req|
  uid = req.params['uid']
  req.response.end("GET USERS\tuid : #{uid}")
end
RM.delete('/users/:uid') do |req|
  uid = req.params['uid']
  req.response.end("DELETE USERS\tuid : #{uid}")
end
RM.delete('/users/:uid/password') do |req|
  uid = req.params['uid']
  req.response.end("DELETE USERS/password\tuid : #{uid}")
end
RM.delete('reset') do |req|
  reset_handler
  req.response.end("RESET FOR DEBUGGING")
end
Server.request_handler(RM) do |req|
#  file = req.uri == "/" ? "index.html" : req.uri
#  req.response.send_file "sven_stock/#{file}"
end.listen(8080, 'localhost')

EB.send('reset', {})

Vertx::set_periodic(3000) do 
  name = (1..5).collect{('a'..'z').to_a[rand * 26 % 26]}.join
  EB.send('/post/user', {username: name, password: '********'}) do |message|
    p "user done : " + message.body.to_s
    EB.send('/post/token', {username: name, password: '********'}) do |message2|
      p "token done : " + message2.body.to_s
      EB.send('/post/token', {username: name, password: '********'}) do |message3|
        p "token2 done : " + message3.body.to_s
        EB.send('/post/token', {username: name, password: 'this--is--not--a--password'}) do |message4|
          p "token3 done : " + message4.body.to_s
        end
      end
    end
  end
end

EB.register_handler('/post/user') do |message|
  post_user_handler (parse2 message.body.to_s), message, 2
end

EB.register_handler('/post/token') do |message|
  post_token_handler (parse2 message.body.to_s), message, 2
end

EB.register_handler('reset') do |message|
  reset_handler
  message.reply("reply")
end

=begin
p "EVENT BUS LINES"
Vertx::EventBus.publish("test.address", 'hello world') do |message|
  puts "I received a reply #{message.body}"
end
Vertx::EventBus.send("test.address", 'hello world') do |message|
  puts "I received a reply #{message.body}"
end
Vertx::set_periodic(1000) do
    Vertx::EventBus.publish('test.address', 'Some news!')
end


myHandler = Vertx::EventBus.register_handler('test.address') do |message|
  puts "Got message body #{message.body}" 
  message.reply('This is a reply')
end

Vertx::EventBus.register_handler('test.address2', myHandler) do
      puts 'Yippee! The handler info has been propagated across the cluster'
end
=end

=begin
Vertx::EventBus.unregister_handler(myHandler) do
      puts 'Yippee! The handler unregister has been propagated across the cluster'
end
=end

=begin
httpServer = Vertx::HttpServer.new.request_handler do |req|
  file = req.uri == "/" ? "sven_stock/index.html" : "sven_stock" + req.uri
  req.response.send_file file 
end

sockJSServer = Vertx::SockJSServer.new(httpServer)
config = { 'prefix' => '/echo' }
sockJSServer.install_app(config) do |sock|
  p "sock is : " + sock.to_s
  #  Vertx::Pump.new(sock, sock).start
  buff = Vertx::Buffer.create_from_str("Hello World", "UTF-8")
  sock.write buff
  #  sock.close
  sock.data_handler do |buffer|
    p "buffer is : " + buffer.to_s
    set = SharedData.get_set("received")
    set.add(buffer.to_s)
    set.each{|x| p "received : " + x}
  end
  sockJSServer.bridge({'prefix' => '/eventbus'}, [], [])

  httpServer.listen(8080)
end
=end


