# A Promise-Based DynamoDB Client

**Dynamo as Promised** is a client for Amazon's [DynamoDB] that returns [promises][promises-presentation] to represent
its asynchronous operations. It is primarily a thin adapter around [dynode][] to transform its Node-style
callback-accepting methods into ones returning [Q][] promises.

This is very much an alpha release: it only supports the small subset of the DynamoDB API that I have found necessary
for other projects. Pull requests and fixes welcome!

## Usage

First, get a client:

```js
var Client = require("dynode-as-promised").Client;
var client = new Client({ accessKeyId: "AWSAccessKey", secretAccessKey: "SecretAccessKey" });
```

Optionally, get a table:

```js
var table = client.table("TableName");
```

Then you have the following methods available, either on the table as documented below, or directly on the client by
passing the table name in as an additional first parameter:

### `table.get(key)`

Corresponds to DynamoDB's [GetItem][] command. Fulfills with a hash representing the returned item.

### `table.query(hash)`

Corresponds to DynamoDB's [Query][] command. Fulfills with an array of hashes representing the returned items.

### `table.scan(scanOptions)`

Corresponds to DynamoDB's [Scan][] command. Fulfills with an array of hashes representing the returned items.

### `table.put(values)`

Corresponds to DynamoDB's [PutItem][] command.

### `table.update(key, values[, options])`

Corresponds to DynamoDB's [UpdateItem][] command.

The option `onlyIfExists` can be supplied in order to do conditional updates. It takes a key name (or object mapping
key types to key names), which is used to build the appropriate `"Expected"` parameters to send to DynamoDB. Example:

```js
customerTable.update("a1b2c3d", { lastName: "Denicola" }, { onlyIfExists: "customerId" });
customerPurchasesTable.update(
    { hash: "a1b2c3d", range: "x1y2z3" },
    { isSatisfied: "true" },
    { onlyIfExists: { hash: "customerId", range: "purchaseId" } }
);
```

### `table.updateAndGet(key, values[, options])`

Corresponds to DynamoDB's [UpdateItem][] command with the `ReturnValues` parameter set to `ALL_NEW`, so that
it can fulfill with a hash representing the updated item. As with `update`, you can supply `options.onlyIfExists` to
do conditional updates.

### `table.delete(key)`

Corresponds to DynamoDB's [DeleteItem][] command.

### `table.deleteMultiple(keys)`

Acts as a wrapper around DynamoDB's [BatchWriteItem][] command, taking an array of keys (of any size) and
using them to perform an appropriate number of delete operations, in batches of 25 at a time (DynamoDB's maximum).



[DynamoDB]: docs.amazonwebservices.com/amazondynamodb/latest/developerguide/Introduction.html?r=5378
[promises-presentation]: http://www.slideshare.net/domenicdenicola/callbacks-promises-and-coroutines-oh-my-the-evolution-of-asynchronicity-in-javascript
[dynode]: https://github.com/Wantworthy/dynode
[Q]: https://github.com/kriskowal/q

[GetItem]: http://docs.amazonwebservices.com/amazondynamodb/latest/developerguide/API_GetItem.html
[PutItem]: http://docs.amazonwebservices.com/amazondynamodb/latest/developerguide/API_PutItem.html
[UpdateItem]: http://docs.amazonwebservices.com/amazondynamodb/latest/developerguide/API_UpdateItem.html
[DeleteItem]: http://docs.amazonwebservices.com/amazondynamodb/latest/developerguide/API_DeleteItem.html
[Query]: http://docs.amazonwebservices.com/amazondynamodb/latest/developerguide/API_Query.html
[Scan]: http://docs.amazonwebservices.com/amazondynamodb/latest/developerguide/API_Scan.html
[BatchWriteItem]: http://docs.amazonwebservices.com/amazondynamodb/latest/developerguide/API_BatchWriteItem.html
