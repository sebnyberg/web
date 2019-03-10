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

The first argument is a filter, which allows you to use both quality comparisons for elements in the document, and more complex queries using operators:

```javascript
db.people.find({ name: "Sebastian" })
db.people.find({ address.zip: "21332" })
db.people.find({ age: { $gt: 25 }})
db.people.find({ address.city: { $in: ["New York", "Berlin"] }})
```

If you have a document with an array field

```javascript
db.people.insert({ name: "Sebastian", feet: ["Left", "Right"]})
```

Then a comparison against that field will compare against each of its elements, i.e. the following returns true:

```javascript
db.people.find({ feet: "Left" })
```
