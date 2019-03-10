+++
title = "Find documents"
date = 2019-03-09T16:03:17+01:00
weight = 3
+++


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
