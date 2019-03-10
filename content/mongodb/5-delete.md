+++
title = "Delete documents"
date = 2019-03-09T16:03:17+01:00
weight = 5
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

### Delete documents

The first argument to delete functions is the same filter as in `find`:

```javascript
db.people.deleteOne({ name: "Sebastian" })
db.people.deleteMany({ name: "Sebastian" })
```