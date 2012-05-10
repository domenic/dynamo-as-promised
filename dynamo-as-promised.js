"use strict";

var dynode = require("dynode");
var Q = require("q");

var BATCH_MAX_SIZE = 25;

function noop() {}
function unary(x) { return x; }

exports.Client = function (options) {
    var dynodeClient = new dynode.Client(options);

    var dynodeClientGetItemAsync = Q.nbind(dynodeClient.getItem, dynodeClient);
    var dynodeClientPutItemAsync = Q.nbind(dynodeClient.putItem, dynodeClient);
    var dynodeClientDeleteItemAsync = Q.nbind(dynodeClient.deleteItem, dynodeClient);
    var dynodeClientUpdateItemAsync = Q.nbind(dynodeClient.updateItem, dynodeClient);
    var dynodeClientScanAsync = Q.nbind(dynodeClient.scan, dynodeClient);
    var dynodeClientBatchWriteItemAsync = Q.nbind(dynodeClient.batchWriteItem, dynodeClient);

    return {
        getAsync: function (table, keys) {
            return dynodeClientGetItemAsync(table, keys).spread(unary);
        },
        putAsync: function (table, values) {
            return dynodeClientPutItemAsync(table, values).then(noop);
        },
        deleteAsync: function (table, keys) {
            return dynodeClientDeleteItemAsync(table, keys).then(noop);
        },
        updateAsync: function (table, keys, values) {
            return dynodeClientUpdateItemAsync(table, keys, values).then(noop);
        },
        scanAsync: function (table, query) {
            return dynodeClientScanAsync(table, query).spread(unary);
        },
        deleteMultipleAsync: function (table, keysArray) {
            var batches = [];
            for (var start = 0; start < keysArray.length; start += BATCH_MAX_SIZE) {
                batches.push(keysArray.slice(start, start + BATCH_MAX_SIZE));
            }

            var deletePromises = batches.map(function (batch) {
                var writes = {};
                writes[table] = batch.map(function (keys) { return { del: keys }; });

                return dynodeClientBatchWriteItemAsync(writes);
            });

            // TODO: could be a bit smarter, report errors better, etc. See
            // https://groups.google.com/forum/#!topic/q-continuum/ZMKqLoaQ5j0
            return Q.allResolved(deletePromises).then(function (resultPromises) {
                var rejectedPromises = resultPromises.filter(function (promise) { return promise.isRejected(); });

                if (rejectedPromises.length > 0) {
                    throw new Error(rejectedPromises.length + "/" + deletePromises.length +
                                    " of the delete batches failed!");
                }
            });
        },
    };
};
