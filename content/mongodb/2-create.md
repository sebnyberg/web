+++
title = "Create documents"
date = 2019-03-09T16:03:17+01:00
weight = 2
+++

## Example document

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

### Insert functions

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

### Something something writeconcern:

```javascript
db.people.insertOne({ name: "Sebastian" },{ writeConcern: { w: 0 }})
```

### Importing data

You can import a document from disk with `mongoimport`:

```bash
mongoimport $FILE -d $DATABASE -c $COLLECTION --jsonArray --drop
```
