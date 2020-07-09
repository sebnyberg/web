+++
title = "Aggregation"
date = 2019-03-09T16:03:17+01:00
weight = 8
+++

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
