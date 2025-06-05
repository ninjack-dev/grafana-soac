# grafana-soac
## Deployment
First, run `./pull_mongo_plugin.sh` to download the latest version of the Grafana MongoDB plugin. If this fails, see [MongoDB Plugin](#mongodb-plugin).

Then, simply run
```
docker compose up -d
```

When initializing the instance for the first time (i.e. when the `grafana.db` file hasn't been migrated), navigate to **Connections** -> **Data Sources**, click **Add New Source** and search for the `MongoDB` plugin; from there, assuming you've been provided a MongoDB connection string, fill out the relevant fields, set the name to `mongodb-datasource`, then **Save and Test**. After that, navigate to `Dashboards`, click **Import** in the upper-righthand corner, then select **Import** in the dropdown menu; from there, you can upload the relevant `SOAC Dashboard.json` from `./dashboard-backups/`.

If you make any changes, make sure to export the dashboard as JSON by clicking **Export** in the upper-righthand corner, selecting **Export as JSON** in the menu

## MongoDB Plugin
We use [haohanyang/mongodb-datasource](https://github.com/haohanyang/mongodb-datasource/) to query the Sandpoint MongoDB; this plugin was an update from the original [JamesOsgood/mongodb-grafana](https://github.com/JamesOsgood/mongodb-grafana).

The script `pull_mongo_plugin.sh` will pull the latest built version of the plugin binaries for use with the Docker setup. **Note: It requires `jq` for parsing the `curl` request and `unzip` for handling the release GitHub release package.** If these dependencies are unavailable for whatever reason, manually download [the latest release of the plugin](https://github.com/haohanyang/mongodb-datasource/releases/latest) and unzip the contents to a new `mongodb-datasource` directory.

### Adding New Panels
#### MongoDB
The MongoDB plugin adds the following variables for use in aggregation pipelines:
- `__from` - The beginning of the time range provided by the Grafana UI. Must be converted to a long before being converted to a [`date`](https://www.mongodb.com/docs/manual/reference/bson-types/#std-label-document-bson-type-date) BSON type; see the example.
- `__to` - The end of the time range provided by the Grafana UI. Must be converted to a long before being converted to a [`date`](https://www.mongodb.com/docs/manual/reference/bson-types/#std-label-document-bson-type-date) BSON type; see the example.
- `<variable name>` - A Grafana variable which can be used in e.g. a [`$match` stage](https://www.mongodb.com/docs/manual/reference/operator/aggregation/match/); see [Adding New Variables](#adding-new-variables).

Because these are provided by Grafana, they must be wrapped in curly braces when used in pipelines, e.g. `${from}`. Note that these are all subject to [Grafana's data transformation rules](https://grafana.com/docs/grafana/latest/panels-visualizations/query-transform-data/transform-data), which may be useful.

To take advantage of the date range, the `time` field associated with each document must be converted to a [`date`](https://www.mongodb.com/docs/manual/reference/bson-types/#std-label-document-bson-type-date) BSON type with [`$dateFromString` operator](https://www.mongodb.com/docs/manual/reference/operator/aggregation/datefromstring/) and added to the document in an [`$addFields` stage](https://www.mongodb.com/docs/manual/reference/operator/aggregation/addFields/). From there, it must be passed to a [`$match` stage](https://www.mongodb.com/docs/manual/reference/operator/aggregation/match/) 
```json
  {
    "$group": {
      "_id": "$time",
      "time": { "$first": "$time" } }
  },
  {
    "$addFields": {
      "time": { "$dateFromString": { "dateString": "$time" } }
    }
  },
  {
    "$match": { "$expr": {
        "$and": [
          { "$gte": [ "$time", { "$toDate": { "$toLong": "${__from}" } } ] },
          { "$lte": [ "$time", { "$toDate": { "$toLong": "${__to}" } } ] }
        ]
      }
    }
  },
```

Feel free to examine any of the panels in the UI itself for more in-depth examples.
#### Images
To add a new image, first put it in `./grafana-public/img`; this is bind mounted to `/var/lib/grafana/public/img/`, and can then be accessed in a Text panel (in HTML mode) with:
```html
<img src=/public/img/your-image.ext>
```
It is **not recommended** to track the images with Git; they will cause storage limit issues in EC2 due to the duplication inherent to Git tracking.

### Adding New Variables
Under **Home** -> **Dashboards** -> **<Dashboard Name>** -> **Settings** -> **Variables**, new variables which rely on the MongoDB database can be added for use in the user interface, e.g. to select a sensor. They must be added via aggregation pipelines which add the field `value` in an [`$addFields` stage](https://www.mongodb.com/docs/manual/reference/operator/aggregation/addFields/).
```json
[
  ...
  {
    "$addFields": {
      "value": "$<your value>"
    }
  }
]
```

### Migration
The original plugin used JavaScript in a similar vein to the [Mongo Shell](https://www.mongodb.com/docs/mongodb-shell/); the queries passed to the `db.<database.aggregate()` call were adapted nearly 1:1 to the new JSON-only format.

The following JQ snippet was used to remove legacy fields from the panels after they were migrated to the new MongoDB plugin.
```jq
. | del(.panels[] | .targets[]? | .target, .type, .datasource)
```
