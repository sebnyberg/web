+++
title = "Mongo shell: CRUD"
date = 2019-03-09T16:03:17+01:00
weight = 2
+++

These sections assume that you have logged into your MongoDB database and have selected a database, which is done with:

```bash
> use mydatabase
```

## Inserting

Insert one or many documents:

```javascript
db.people.insertOne({ name: "Sebastian" })
db.people.insertMany([{ name: "Sebastian" },{ name: "Jesper" })
```

Regular inserts are ordered, meaning that an error will stop insertion of subsequent documents. To change this behaviour, set ordered to `false`:

```javascript
// This will not insert the third document 
db.people.insertMany([{ _id: 1 },{ _id: 1 },{ _id: 2 }])

// This will insert both the first and third document
db.people.insertMany([{ _id: 1 },{ _id: 1 },{ _id: 2 }], { ordered: false })
```

Something something writeconcern:

```javascript
db.people.insertOne({ name: "Sebastian" },{ writeConcern: { w: 0 }})
```

#### Importing data

You can import a document from disk with `mongoimport`:

```bash
mongoimport $FILE -d $DATABASE -c $COLLECTION --jsonArray --drop
```

## Finding data

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

{{% notice note %}}
Skip and limit will happen after sorting of the document. This makes sense when you consider that the sort itself does not actually sort records, it returns a list of indices which point towards the documents in sorted order.
{{% /notice%}}

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

## Updating

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

// Update a matched element of an array
db.people.updateOne(
    {addresses: {$elemMatch: {city: "Montevideo"}}},
    {$set: {"addresses.$": {city: "Minas", zip: "32333"}}}
  )

// Update only one field of that element
// Note: if you set a field which does not exist it will be created
db.people.updateOne(
    {addresses: {$elemMatch: {city: "Montevideo"}}},
    {$set: {"addresses.$.city": "Minas"}}
  )

```

#### Upserting

Upserting is the process of inserting a document when no document was found for the update. This is very powerful, for example if you were in the process of inserting documents and it failed, you can re-run the same query with upserts without having to worry about duplicates.

The field that was matched in the filter will be included in the created document.

```javascript
db.people.updateOne({name: "Eric"}, {$set: {age: 22}}, {upsert: true})