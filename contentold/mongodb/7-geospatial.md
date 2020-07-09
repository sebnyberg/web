+++
title = "Geospatial queries"
date = 2019-03-09T16:03:17+01:00
weight = 7
+++

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