+++
title = "Mongo shell: CRUD"
date = 2019-03-09T16:03:17+01:00
weight = 2
+++

These sections assume that you have logged into your MongoDB database and have selected a database, which is done with:

```bash
> use mydatabase
```

### `insertMany` and `insertOne`

Insertion happens with `insertMany` and `insertOne`:

```javascript
db.people.insertOne({ name: "Sebastian Nyberg" })
db.people.insertMany([{ name: "Sebastian Nyberg" },{ name: "Jesper Nyberg" })
```

Running these commands will automatically generate a sequential id called `_id`, which is of type `ObjectID`.

```bash
rs0:PRIMARY> db.people.insertOne({ name: "Sebastian" })
{
        "acknowledged" : true,
        "insertedId" : ObjectId("5c842221c69cdfad53bf2030")
}
rs0:PRIMARY> db.people.find().pretty()
{ "_id" : ObjectId("5c842221c69cdfad53bf2030"), "name" : "Sebastian" }
```

ObjectID is a sequential unique identifier. If you want to specify the `_id` field, simply pass it with the record:

```javascript
rs0:PRIMARY> db.people.insertOne({ _id: "J", name: "Jesper"})
{ "acknowledged" : true, "insertedId" : "J" }
rs0:PRIMARY> db.people.find().pretty()
{ "_id" : ObjectId("5c842221c69cdfad53bf2030"), "name" : "Sebastian" }
{ "_id" : "J", "name" : "Jesper Nyberg" }
```

{{% notice note %}}
If you pass your own `_id`, it needs to be unique.
{{% /notice%}}

#### Ordered versus unordered inserts

The default option of insert queries is to handle each insertion in order, and cancel subsequent queries if an error occurs. Previous inserts do not roll back however.

For example, the query below will not insert the third record, because the second record triggered an error:

```javascript
rs0:PRIMARY> db.people.insertMany([{_id: "S", name: "Sebastian"},{_id: "S", name: "Sebastian2"},{_id: "J", name: "Jesper"}])
2019-03-09T21:49:22.564+0100 E QUERY    [js] BulkWriteError: write error at item 1 in bulk operation :
BulkWriteError({
        "writeErrors" : [
                {
                        "index" : 1,
                        "code" : 11000,
                        "errmsg" : "E11000 duplicate key error collection: temp.people index: _id_ dup key: { : \"S\" }",
                        "op" : {
                                "_id" : "S",
                                "name" : "Sebastian2"
                        }
                }
        ],
        "writeConcernErrors" : [ ],
        "nInserted" : 1,
        "nUpserted" : 0,
        "nMatched" : 0,
        "nModified" : 0,
        "nRemoved" : 0,
        "upserted" : [ ]
})
BulkWriteError@src/mongo/shell/bulk_api.js:369:48
BulkWriteResult/this.toError@src/mongo/shell/bulk_api.js:333:24
Bulk/this.execute@src/mongo/shell/bulk_api.js:1173:1
DBCollection.prototype.insertMany@src/mongo/shell/crud_api.js:314:5
@(shell):1:1
```

Since the insertion is ordered, the record second record was never inserted:

```javascript
rs0:PRIMARY> db.people.find()
{ "_id" : "S", "name" : "Sebastian" }
```

If you want to change this behaviour, the second argument to the `insertMany` and `insertOne` function is a list of options. You can set the option `ordered` to `false` to change the behaviour above:

```javascript
rs0:PRIMARY> db.people.insertMany([{_id: "S", name: "Sebastian"},{_id: "S", name: "Sebastian2"},{_id: "J", name: "Jesper"}], {ordered: false})
2019-03-09T22:30:21.443+0100 E QUERY    [js] BulkWriteError: write error at item 1 in bulk operation :
BulkWriteError({
        "writeErrors" : [
                {
                        "index" : 1,
                        "code" : 11000,
                        "errmsg" : "E11000 duplicate key error collection: test.people index: _id_ dup key: { : \"S\" }",
                        "op" : {
                                "_id" : "S",
                                "name" : "Sebastian2"
                        }
                }
        ],
        "writeConcernErrors" : [ ],
        "nInserted" : 2,
        "nUpserted" : 0,
        "nMatched" : 0,
        "nModified" : 0,
        "nRemoved" : 0,
        "upserted" : [ ]
})
BulkWriteError@src/mongo/shell/bulk_api.js:369:48
BulkWriteResult/this.toError@src/mongo/shell/bulk_api.js:333:24
Bulk/this.execute@src/mongo/shell/bulk_api.js:1173:1
DBCollection.prototype.insertMany@src/mongo/shell/crud_api.js:314:5
@(shell):1:1
rs0:PRIMARY> db.people.find().pretty()
{ "_id" : "S", "name" : "Sebastian" }
{ "_id" : "J", "name" : "Jesper" }
```

