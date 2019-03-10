+++
title = "Indexes"
date = 2019-03-09T16:03:17+01:00
weight = 6
+++

## Indexes

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

{{% notice note %}}
Adding an index to an existing collection does not actually apply the TTL to its records. This happens when you insert the first document after its creation.
{{% /notice%}}

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

{{% notice note %}}
You may only have one text index per collection.
{{% /notice %}}

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
