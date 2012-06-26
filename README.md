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

Then you have the following methods available:

### `client.get(table, key)`

Corresponds to DynamoDB's [GetItem][] command. Fulfills with a hash representing the returned item.

### `client.query(table, hash)`

Corresponds to DynamoDB's [Query][] command. Fulfills with an array of hashes representing the returned items.

### `client.scan(table, options)`

Corresponds to DynamoDB's [Scan][] command. Fulfills with an array of hashes representing the returned items.

### `client.put(table, values)`

Corresponds to DynamoDB's [PutItem][] command.

### `client.update(table, key, values[, options])`

Corresponds to DynamoDB's [UpdateItem][] command. If `options.onlyIfExists` is true, will send the appropriate
`"Expected"` options to DynamoDB so as to only perform the update if the keys match those passed in `values`.

### `client.updateAndGet(table, key, values[, options])`

Corresponds to DynamoDB's [UpdateItem][] command with the `ReturnValues` parameter set to `ALL_NEW`, so that
it can fulfill with a hash representing the updated item. If `options.onlyIfExists` is true, will send the appropriate
`"Expected"` options to DynamoDB so as to only perform the update if the keys match those passed in `values`.

### `client.delete(table, key)`

Corresponds to DynamoDB's [DeleteItem][] command.

### `client.deleteMultiple(table, keys)`

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
