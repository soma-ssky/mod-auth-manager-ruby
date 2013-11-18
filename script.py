import json,httplib

con = httplib.HTTPConnection("localhost:8080")
con.connect() #not necessary, maybe

def test(verb, url, json = None):
  con.request(verb, url, json)
  r = con.getresponse()
  print str(r.status) + " " + r.reason
  return r.read()


test("DELETE", "reset") # reset

#(user) sign up
uid = test("POST", "/users", json.dumps({
  "username" : "sven",
  "password" : "****"}))
print "uid is : " + str(uid) #TODO get uid only

#(user) get token
token = test("POST", "/tokens", json.dumps({
  "username" : "sven",
  "password" : "****"}))
print "token is : " + token

#(provider) get user
test("GET", "/users/" + uid)
#(user? provider) update user
test("PUT", "/users/" + uid)
#(user? provider) delete user
test("DELETE", "/users/" + uid)
#(user) require new password
test("DELETE", "/users/" + uid + "/password")





'''
connection = httplib.HTTPSConnection('api.parse.com')
print connection
connection.connect()
connection.request('POST', '/1/users', json.dumps({
       "username": "cooldude6",
       "password": "p_n7!-e8",
       "phone": "415-392-0202"
     }), {
       "X-Parse-Application-Id": "${APPLICATION_ID}",
       "X-Parse-REST-API-Key": "${REST_API_KEY}",
       "Content-Type": "application/json"
     })
result = json.loads(connection.getresponse().read())
print result
'''

'''
curl -X POST \
  -H "X-Parse-Application-Id: ${APPLICATION_ID}" \
  -H "X-Parse-REST-API-Key: ${REST_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"username":"cooldude6","password":"p_n7!-e8","phone":"415-392-0202"}' \
  https://api.parse.com/1/users
'''

