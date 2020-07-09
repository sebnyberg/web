+++
title = "Adding auth and users"
date = 2019-03-09T16:03:17+01:00
weight = 2
+++

```javascript
use admin

db.createUser({user: "myusername", pwd: "mypassword", roles: ["userAdminAnyDatabase"]})

db.auth('myusername', 'mypassword')

use appdb

db.createUser({user: "appdev", pwd: "dev", roles: [ "readWrite" ]})

db.logout()

db.auth('appdev', 'dev')

db.updateUser("appdev", {pwd: "newpassword})
db.updateUser("appdev", {roles: ["readWrite", {role: "readWrite", db: "otherappdb"}]})
db.getUser("appdev")
```

#### Built-in roles [Docs](https://docs.mongodb.com/manual/reference/built-in-roles)

