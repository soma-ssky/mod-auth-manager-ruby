require 'rubygems'
require 'mongo'
include Mongo
mongo_client = MongoClient.new("localhost", 27017)
db = mongo_client.db("ruby_db")
coll = db.collection("test_collection")
doc = {"name" => "MongoDB", "type" => "database", "count" => 1, "info" => {"x" => 203, "y" => '102'}}
id = coll.insert(doc)
p mongo_client.database_names
p db.collection_names
p id
p coll.find_one

