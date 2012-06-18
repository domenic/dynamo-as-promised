"use strict";

var dynode = require("dynode");
var Q = require("q");

// See http://docs.amazonwebservices.com/amazondynamodb/latest/developerguide/API_BatchWriteItem.html
var BATCH_MAX_SIZE = 25;

function noop() {}              // Used to swallow returned metadata from dynode
function unary(x) { return x; } // Used with `spread` to transform (data, metadata) pairs from dynode into just data

exports.Client = function (options) {
    var dynodeClient = new dynode.Client(options);

    var dynodeClientGetItemAsync = Q.nbind(dynodeClient.getItem, dynodeClient);
    var dynodeClientPutItemAsync = Q.nbind(dynodeClient.putItem, dynodeClient);
    var dynodeClientDeleteItemAsync = Q.nbind(dynodeClient.deleteItem, dynodeClient);
    var dynodeClientUpdateItemAsync = Q.nbind(dynodeClient.updateItem, dynodeClient);
    var dynodeClientScanAsync = Q.nbind(dynodeClient.scan, dynodeClient);
    var dynodeClientBatchWriteItemAsync = Q.nbind(dynodeClient.batchWriteItem, dynodeClient);

    return {
        getAsync: function (table, key) {
            return dynodeClientGetItemAsync(table, key).spread(unary);
        },
        putAsync: function (table, values) {
            return dynodeClientPutItemAsync(table, values).then(noop);
        },
        deleteAsync: function (table, key) {
            return dynodeClientDeleteItemAsync(table, key).then(noop);
        },
        updateAsync: function (table, key, values) {
            return dynodeClientUpdateItemAsync(table, key, values).then(noop);
        },
        updateAndGetAsync: function (table, key, values) {
            return dynodeClientUpdateItemAsync(table, key, values, { ReturnValues: "ALL_NEW" }).get("Attributes");
        },
        scanAsync: function (table, query) {
            return dynodeClientScanAsync(table, query).spread(unary);
        },
        deleteMultipleAsync: function (table, keys) {
            var batches = [];
            for (var start = 0; start < keys.length; start += BATCH_MAX_SIZE) {
                batches.push(keys.slice(start, start + BATCH_MAX_SIZE));
            }

            var deletePromises = batches.map(function (batch) {
                var writes = {};
                writes[table] = batch.map(function (key) { return { del: key }; });

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
