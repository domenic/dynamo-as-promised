# A Promise-Based DynamoDB Client

**Dynamo as Promised** is a client for Amazon's [DynamoDB] that returns [promises][promises-presentation] to represent
its asynchronous operations. It is primarily a thin adapter around [dynode][dynode] to transform its Node-style
callback-accepting methods into ones returning [Q][Q] promises.

This is very much an alpha release: it only supports the small subset of the DynamoDB API that I have found necessary
for other projects. Pull requests and fixes welcome!

## Usage

First, get a client:

```js
var Client = require("dynode-as-promised").Client;
var client = new Client({accessKeyId: "AWSAccessKey", secretAccessKey: "SecretAccessKey"});
```

Then you have the following methods available:

### `client.getAsync(table, key)`

Corresponds to DynamoDB's [GetItem][GetItem] command. Fulfills with a hash representing the returned item.

### `client.scanAsync(table, query)`

Corresponds to DynamoDB's [Scan][Scan] command. Fulfills with an array of hashes representing the returned items.

### `client.putAsync(table, values)`

Corresponds to DynamoDB's [PutItem][PutItem] command.

### `client.updateAsync(table, key, values)`

Corresponds to DynamoDB's [UpdateItem][UpdateItem] command.

### `client.updateAndGetAsync(table, key, values)`

Corresponds to DynamoDB's [UpdateItem][UpdateItem] command with the `ReturnValues` parameter set to `ALL_NEW`, so that
it can fulfill with a hash representing the updated item.

### `client.deleteAsync(table, key)`

Corresponds to DynamoDB's [DeleteItem][DeleteItem] command.

### `client.deleteMultipleAsync(table, keys)`

Acts as a wrapper around DynamoDB's [BatchWriteItem][BatchWriteItem] command, taking an array of keys (of any size) and
using them to perform an appropriate number of delete operations, in batches of 25 at a time (DynamoDB's maximum).

---

Wondering about the `Async` suffix? It's a convention I'm borrowing [from the Windows Runtime API][winrt-async], as a
way of differentiating promise-returning functions from synchronous functions or functions that use Node-style
callbacks. To be honest, I'm not sure if I like it, so that might go away in the future.



[DynamoDB]: docs.amazonwebservices.com/amazondynamodb/latest/developerguide/Introduction.html?r=5378
[promises-presentation]: http://www.slideshare.net/domenicdenicola/callbacks-promises-and-coroutines-oh-my-the-evolution-of-asynchronicity-in-javascript
[dynode]: https://github.com/Wantworthy/dynode
[Q]: https://github.com/kriskowal/q

[GetItem]: http://docs.amazonwebservices.com/amazondynamodb/latest/developerguide/API_GetItem.html
[PutItem]: http://docs.amazonwebservices.com/amazondynamodb/latest/developerguide/API_PutItem.html
[UpdateItem]: http://docs.amazonwebservices.com/amazondynamodb/latest/developerguide/API_UpdateItem.html
[DeleteItem]: http://docs.amazonwebservices.com/amazondynamodb/latest/developerguide/API_DeleteItem.html
[Scan]: http://docs.amazonwebservices.com/amazondynamodb/latest/developerguide/API_Scan.html
[BatchWriteItem]: http://docs.amazonwebservices.com/amazondynamodb/latest/developerguide/API_BatchWriteItem.html
[winrt-async]: http://msdn.microsoft.com/en-us/library/windows/apps/hh464924.aspx
