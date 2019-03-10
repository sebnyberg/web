+++
title = "Update documents"
date = 2019-03-09T16:03:17+01:00
weight = 4
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

## Update documents

Quick examples:

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

{{% notice note %}}
If you set a field which does not exist, it will be created
{{% /notice%}}

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

{{% notice note %}}
This does not work in Cosomos DB - don't ask me why.
{{% /notice%}}

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