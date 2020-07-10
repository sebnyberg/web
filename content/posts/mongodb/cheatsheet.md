+++
title = "MongoDB - Cheat Sheet"
date = "2019-03-09T16:03:17+01:00"
author = "Sebastian"
subtitle = "Basic operations in MongoDB"
tags = [ "mongodb" ]
categories = [ "databases" ]
+++

A cheat sheet with basic operations in MongoDB

## Setup - Kubernets

Assuming that you have [Helm](https://helm.sh/) installed, there are two charts of interest:

* [stable/mongodb](https://github.com/helm/charts/tree/master/stable/mongodb)
* [stable/mongodb-replicaset](https://github.com/helm/charts/tree/master/stable/mongodb-replicaset)

For most use cases, especially if you are starting out with MongoDB, it makes sense to go for the first one. Once you are familiar with- and there's a need for replica sets, switch to the second one.

Install with

```bash
helm install stable/mongodb
```

or

```bash
RELEASE_NAME=my-mongodb

helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm install --name $RELEASE_NAME stable/mongodb-replicaset
```

Give the installation a while then check pod status:

```bash
kubectl get pods
```

By default, the replicaset will choose the first node as the master.

### Local development

For testing purposes, you can run a local port-forward to the mongodb pod and access it via localhost:

```bash
first_mongo_pod=$(kubectl get pods | awk '$1 ~ /mongo/ { print $1; exit }')
kubectl port-forward $first_mongo_pod 27017:27017
```

<!-- Notice! -->
In case you are new to awk, awk will traverse each row of the `kubectl get pods` command and store each field in $i, i > 0. If the first field contains the word "mongo", the statement within curly braces will be executed, and the `exit` command will stop further execution.

You can now connect to the database with Mongo Shell locally:

```bash
$ mongo
MongoDB shell version v4.0.5
connecting to: mongodb://127.0.0.1:27017/?gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("a259c4a2-d765-4957-bd35-4ad9220c65d2") }
MongoDB server version: 3.6.11
WARNING: shell and server versions do not match
Server has startup warnings:
2019-03-08T21:45:29.929+0000 I STORAGE  [initandlisten]
2019-03-08T21:45:29.929+0000 I STORAGE  [initandlisten] ** WARNING: Using the XFS filesystem is strongly recommended with the WiredTiger storage engine
2019-03-08T21:45:29.929+0000 I STORAGE  [initandlisten] **          See http://dochub.mongodb.org/core/prodnotes-filesystem
2019-03-08T21:45:31.415+0000 I CONTROL  [initandlisten]
2019-03-08T21:45:31.415+0000 I CONTROL  [initandlisten] ** WARNING: Access control is not enabled for the database.
2019-03-08T21:45:31.415+0000 I CONTROL  [initandlisten] **          Read and write access to data and configuration is unrestricted.
2019-03-08T21:45:31.415+0000 I CONTROL  [initandlisten]
2019-03-08T21:45:31.415+0000 I CONTROL  [initandlisten]
2019-03-08T21:45:31.415+0000 I CONTROL  [initandlisten] ** WARNING: /sys/kernel/mm/transparent_hugepage/enabled is 'always'.
2019-03-08T21:45:31.415+0000 I CONTROL  [initandlisten] **        We suggest setting it to 'never'
2019-03-08T21:45:31.415+0000 I CONTROL  [initandlisten]
rs0:PRIMARY>
```

## Adding users

```javascript
use admin

db.createUser({user: "myusername", pwd: "mypassword", roles: ["userAdminAnyDatabase"]})

db.auth('myusername', 'mypassword')

use appdb

db.createUser({user: "appdev", pwd: "dev", roles: [ "readWrite" ]})

db.logout()

db.auth('appdev', 'dev')

db.updateUser("appdev", {pwd: "newpassword"})
db.updateUser("appdev", {roles: ["readWrite", {role: "readWrite", db: "otherappdb"}]})
db.getUser("appdev")
```

### Built-in roles [Docs](https://docs.mongodb.com/manual/reference/built-in-roles)

## Create documents

Make sure you have selected the database:

```javascript
use mydatabase
```

Insert the example document:

```javascript
var me = {
  name: "Sebastian",
  age: 28,
  addresses: [
    {
      city: "Montevideo",
      zip: "51449",
    },
    {
      city: "Malmo",
      zip: "26635",
    },
  ],
  friends: [
    "Bob",
    "Alice",
  ],
}
db.people.insert(me)
```

### Insert document(s)

Insert one or many documents:

```javascript
db.people.insertOne({ name: "Sebastian" })
db.people.insertMany([{ name: "Sebastian" },{ name: "Jesper" })
```

### Ordered inserts

Regular inserts are ordered, meaning that an error will stop insertion of subsequent documents. To change this behaviour, set ordered to `false`:

```javascript
// This will not insert the third document 
db.people.insertMany([{ _id: 1 },{ _id: 1 },{ _id: 2 }])

// This will insert both the first and third document
db.people.insertMany([{ _id: 1 },{ _id: 1 },{ _id: 2 }], { ordered: false })
```

<!-- ### Something something writeconcern

```javascript
db.people.insertOne({ name: "Sebastian" },{ writeConcern: { w: 0 }})
``` -->

### Import data

You can import a document from disk with `mongoimport`:

```bash
mongoimport mydata.json -d $DATABASE -c $COLLECTION --jsonArray --drop
```

## Read data 


Make sure you have selected your database:

```javascript
use mydatabase
```

Insert the example document:

```javascript
var me = {
  name: "Sebastian",
  age: 28,
  addresses: [
    {
      city: "Montevideo",
      zip: "51449",
    },
    {
      city: "Malmo",
      zip: "26635",
    },
  ],
  friends: [
    "Bob",
    "Alice",
  ],
}
db.people.insert(me)
```

### Find document(s)

Find one document:

```javascript
db.people.findOne()
```

`find` returns a cursor that can be used to iterate over rows in the response

```javascript
db.people.find()
```

```javascript
var me = {
  name: "Sebastian",
  age: 28,
  address: {
    city: "Montevideo",
    zip: "51449",
  },
  friends: [
    "Bob",
    "Alice",
  ]
}
db.people.insert(me)
```

These will all match the document above:

```bash
db.people.find({ name: "Sebastian" })
db.people.find({ address.zip: "21332" })
db.people.find({ friends: "Bob" })
db.people.find({ friends: ["Alice", "Bob"] })
```

#### $gt 

```javascript
db.people.find({ age: { $gt: 25 }})
```

#### $in

```javascript
db.people.find({ address.city: { $in: ["New York", "Berlin"] }})
```

#### $or

```javascript
db.people.find({ $or: [ { address.city: "New York" }, { name: "Sebastian" } ]})
```

#### $exists

```javascript
db.people.find({ friends: { $exists: true }})
```

#### $type

```javascript
db.people.find({ friends: { $type: "array" }})
db.people.find({ address.zip: { $type: ["string", "number"] }})
```

#### $regex

```javascript
db.people.find({ name: { $regex: /bastian/ }})
```

#### $expr

`$expr` allows for referencencing fields in a document as $-prefixed strings, letting you write a filter which compares the document with itself:

```javascript
// This will faill obviously, very few people are as old as their zipcodes
db.people.find({ $expr: { $eq: ["$age", "$zip"] }})
```

There is a more complex version of $expr, which allows for an `if...then` clause:

```javascript
db.people.find({ $expr: { $cond: }})
```

#### Sorting

```javascript
// Ascending
db.people.find().sort({"age": 1})

// Descending
db.people.find().sort({"age": -1})

// Second sort criterion
db.people.find().sort({"age": -1, "name": -1})
```

#### Skip & limit

<!-- Notice! -->
Skip and limit will happen after sorting of the document. This makes sense when you consider that the sort itself does not actually sort records, it returns a list of indices which point towards the documents in sorted order.

```javascript
db.people.find().skip(1)
db.people.find().skip(10).limit(10)
```

#### Projection

The second, optional argument to `find` is the projection. The projection determines which fields should be retrieved in the output

```javascript
// Only retrieve the name
db.people.find({}, {name: 1})

// Retrieve the name and age
db.people.find({}, {name: 1, age: 1})
```

If you want to filter out only some matching elements of an array, you can use the `"field.$": 1` syntax to print one (1) matching field. This requires you to provide a filter, otherwise the list of matches is empty:

```javascript
db.people.find({friends: "Bob"}, {"friends.$": 1})
```

If you want a projection that includes an element that was not matched in the filter, you can use `$elemMatch`:

```javascript
db.people.find({friends: "Bob"}, {friends: {$elemMatch: {$eq: "Alice"}}})
```

## Update data

Make sure you have selected your database:

```javascript
use mydatabase
```

Insert the example document:

```javascript
var me = {
  name: "Sebastian",
  age: 28,
  addresses: [
    {
      city: "Montevideo",
      zip: "51449",
    },
    {
      city: "Malmo",
      zip: "26635",
    },
  ],
  friends: [
    "Bob",
    "Alice",
  ],
}
db.people.insert(me)
```

### Update documents

```javascript
db.people.updateOne({name: "Sebastian"}, {$set: {name: "Bulbastian"}})

// Change the name and set age to 29
db.people.updateOne({name: "Sebastian"}, {$set: {name: "Bulbastian", age: 29}})

// Increment age by 1
db.people.updateOne({name: "Sebastian"}, {$inc: {age: 1}})

// Change the name and increment age by 1
db.people.updateOne({name: "Sebastian"}, {$set: {name: "Bulbastian"}, $inc: {age: 1}})

// Remove Alice as a friend :(
db.people.updateOne({name: "Sebastian"}, {$set: {friends: ["Bob"]}})

// $min sets an upper bound of what is acceptable, i.e. it changes all values > 25 to 25
db.people.updateOne({name: "Sebastian"}, {$min: {age: 25}})

// $max sets a lowerbound, i.e. age: 28 sets all ages lower than 28 to 28
db.people.updateOne({name: "Sebastian"}, {$max: {age: 28}})

// Drop the age field
db.people.updateOne({name: "Sebastian"}, {$unset: {age: ""}})

// Rename name -> firstName
db.people.updateOne({name: "Sebastian"}, {$rename: {name: "firstName"}})
```

### Filter and set all elements of an array

```javascript
db.people.updateOne(
    {addresses: {$elemMatch: {city: "Montevideo"}}},
    {$set: {"addresses.$": {city: "Minas", zip: "32333"}}}
  )
```

### Filter documents by array and set field in the first matching element of each document

<!-- Notice! -->
If you set a field which does not exist, it will be created

```javascript
db.people.updateOne(
    {addresses: {$elemMatch: {city: "Montevideo"}}},
    {$set: {"addresses.$.city": "Minas"}}
  )
```

### Filter documents by array and set field for all elements 

```javascript
db.people.updateOne(
    {name: "Sebastian"}
    {$set: {"addresses.$[].city": "Minas"}}
  )
```

### Filter documents and set value based off another filter

<!-- Notice! -->
This does not work in Cosomos DB - don't ask me why.

Finally, if you want to update a record based on a filter other than the one that filters out matching documents, you can use arrayFilters.

Example: find all people who live in Montevideo, set their non-montevideo cities to be "Not Montevideo":

```javascript
db.people.updateOne(
  {"addresses.city": "Montevideo"},
  {$set: {"addresses.$[el].city": "Not Montevideo"}},
  {arrayFilters: [{"el.city": {$not: {$eq: "Montevideo"}}}]}
)
```

### Add an element to a document

Adding generally happens with `$push`

```javascript
db.people.updateOne(
    { name: "Sebastian" },
    {
      $push: {
        addresses: { city: "Minas", zip: "23133" }
      }
      // if you only want to push if the element doesn't already exist
      // $addToSet: {...}
    }
  )
```

### Add elements to a document

```javascript
db.people.updateOne(
    { name: "Sebastian" },
    {
      $push: {
        addresses: {
          $each: [{city: "Minas"}, {city: "Boston"}],
          // you can add $sort here too e.g. sorting by city descending
          // $sort: {city: -1}
        }
      }
    }
  )
```

### Remove elements from a document

This will remove all elements which match the criterion:

```javascript
db.people.updateOne(
    { name: "Sebastian" },
    {
      $pull: {
        addresses: {
          city: "Minas"
        }
      }
    }
  )
```

### Remove the last or first element from an array

```javascript
db.people.updateOne(
    { name: "Sebastian" },
    {
      $pop: {
        addresses: 1
        // this will pop the first element:
        addresses: -1
      }
    }
  )
```

### Upserting

Upserting is the process of inserting a document when no document was found for the update. This is very powerful, for example if you were in the process of inserting documents and it failed, you can re-run the same query with upserts without having to worry about duplicates.

The field that was matched in the filter will be included in the created document.

```javascript
db.people.updateOne({name: "Eric"}, {$set: {age: 22}}, {upsert: true})
```

## Delete

Make sure you have selected your database:

```javascript
use mydatabase
```

Insert the example document:

```javascript
var me = {
  name: "Sebastian",
  age: 28,
  addresses: [
    {
      city: "Montevideo",
      zip: "51449",
    },
    {
      city: "Malmo",
      zip: "26635",
    },
  ],
  friends: [
    "Bob",
    "Alice",
  ],
}
db.people.insert(me)
```

### Delete documents

The first argument to delete functions is the same filter as in `find`:

```javascript
db.people.deleteOne({ name: "Sebastian" })
db.people.deleteMany({ name: "Sebastian" })
```

### Transactions

In order to ensure that several deletes go through before you commit to the deletion, use a transaction:

```javascript
const session = db.getMongo().startSession()
session.startTransaction()

const someColl = session.getDatabase("mydatabase").someCollection
const anotherColl = session.getDatabase("mydatabase").anotherCollection

someColl.deleteOne()
anotherColl.deleteOne()

session.commitTransaction()
// or if it failed:
session.abortTransaction()
```

## Indexing

Without any index, your queries will run a complete scan, this is reflected in the `explain()`, which will contain a winning plan with a stage of "COLLSCAN"

```javascript
db.people.explain().find()
db.people.explain("executionStats").find()
db.people.explain("queryPlanner").find()

// Tests all indexes
db.people.explain("allPlansExecution").find()
```

A good index has most of the keys that are examined in the query, i.e. the number of keys in the index should be near equal to that of the number of documents that are examined.

The winning plan for a query will be cached until an index is added or removed from the same collection, a certain amount of documents have been added, if the index is rebuilt or if the server restarts.

### Simple index

```javascript
db.people.createIndex({"name": 1})

// Descending
db.people.createIndex({"name": -1})
```

If an index is placed on a field which is an array, all top-level elements of that array will be indexed. This is called a multi-key index. A multi-key index can not be used in combination (compounded) with another multi-key index.

### Compound index

```javascript
db.people.createIndex({"name": 1, "age": 1})
```

### Unique index

```javascript
db.people.createIndex({"name": 1}, {unique: true})
```

### Index parts of the collection

```javascript
// Only add an index for old people
db.people.createIndex(
    {"age": 1},
    {
      partialFilterExpression: {
        "age": { $gt: 50 }
      }
    })
```

### TTL index

<!-- Notice! -->
Adding an index to an existing collection does not actually apply the TTL to its records. This happens when you insert the first document after its creation.

This will delete documents 10 seconds after the createdAt date:

```javascript
db.people.createIndex(
  { "createdAt": 1 },
  { expireAfterSeconds: 10 }
)
```

### Covered queries

Covered queries are similar to materialized views in Postgres, they store the result of a query so that the query can immediately return its result when used:

```javascript
db.people.createIndex(
  { "name": 1 }
)
```

The following query will simply return the index:

```javascript
db.people.find(
  { "name": "Sebastian" },
  // Exclude _id since it's not part of the index
  { _id: 0}
)
```

### Text index

<!-- Notice! -->
You may only have one text index per collection.

Just like an index can be either _ascending_ or _descending_ when set to 1 or -1, it may also be of type `"text"`. This improves the speed text-searches.

```javascript
db.people.createIndex({ "name": "text" })

// create an index for two fields
db.people.createIndex({ "name": "text", "email": "text" })

// options
db.people.createIndex(
  { "name": "text", "email": "text" },
  {
    default_language: "english",
    weights: {
      "name": 10,
      "email": 1,
    }
  }
)

```

You can now search for text using this index:

```javascript
// Find documents with a name of "Sebastian"
db.people.find({ $text: { $search: "bastian" } })

// Find documents which do not have "bastian" in them
db.people.find({ $text: { $search: "-bastian" } })

// Find documents with a name of Sebastian or Bob
db.people.find({ $text: { $search: "Sebastian Bob" } })

// Find documents with a name of "Sebastian Bob"
db.people.find({ $text: { $search: '"Sebastian Bob"' } })

// Find documents using a non-default language
db.people.find(
  {
    $text: {
      $search: '"Sebastian Bob"',
      $language: "swedish",
      // default caseSensitive is false
      $caseSensitive: true
    }
  }
)

// Show scores for matches and sort by score
db.people.find(
  { $text: { $search: '"Sebastian Bob"' } },
  { score: { $meta: "textScore" } },
).sort(
  { score: { $meta: "textScore" } }
)
```

### Creating indexes in the background

```javascript
db.people.createIndex({ "name": 1 }, { background: true })
```

### Dropping indexes

```javascript
db.people.getIndexes()
db.people.dropIndex(INDEX_NAME)
db.people.dropIndex({ "name": "text" })
```

## Geo-spatial capabilities

### [Link to MongoDB docs](https://docs.mongodb.com/manual/geospatial-queries/)

Create a new location (Montevideo)

```javascript
use geo

db.places.insertOne({
  geom: {
    type: "Point",
    coordinates: [
      -34.821018, -56.3765222
    ]
  }
})
```

To run geospatial queries against the collection, create a geospatial index:

```javascript
db.places.createIndex({ geom: "2dsphere" })
```

### Find places near a location

```javascript
var pointNearMontevideo = {
  type: "Point",
  coordinates: [
    -34.821018, -56.3
  ]
}

db.places.find({
  geom: {
    $near: {
    $geometry: pointNearMontevideo,
    $maxDistance: 10000
  }
})
```

### Find places within an area

```javascript
var areaInMontevideo = {
  type: "Polygon",
  coordinates: [[
    [ -34.0, -56.0 ],
    [ -35.0, -56.0 ],
    [ -35.0, -57.0 ],
    [ -34.0, -57.0 ],
    [ -34.0, -56.0 ],
  ]]
}

db.places.find({
  geom: {
    $geoWithin: {
      $geometry: areaInMontevideo
    }
  }
})
```

### Create an area from a point

```javascript
var pointNearMontevideo = {
  type: "Point",
  coordinates: [
    -34.821018, -56.3
  ]
}
var radius = 1500
var radiusInRadians = radius / 6.3781

db.places.find({
  geom: {
    $geoWithin: {
      $centerSphere: [
        pointNearMontevideo.coordinates,
        radiusInRadians
      ]
    }
  }
})
```

## Aggregation

### [Link to MongoDB docs](https://docs.mongodb.com/manual/aggregation/)

Aggregation is a powerful tool to project and run different aggregations on your documents. There is a large set of operators you can use (see link above). Here's a small example:

```javascript
db.people.aggregate([
  { $project: { _id: 0, age: 1, name: 1, fullName: { $concat: { "firstName", " ", "$lastName" }}}},
  { $match: { age: { $gt: 20 } }, },
  { $group: { _id: { name: "$name" }, peopleWithSameName: { $sum: 1 } } },
  { $sort: { peopleWithSameName: -1 }}
])
```
