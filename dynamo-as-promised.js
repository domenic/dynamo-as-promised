"use strict";

var dynode = require("dynode");
var Q = require("q");

// See http://docs.amazonwebservices.com/amazondynamodb/latest/developerguide/API_BatchWriteItem.html
var BATCH_MAX_SIZE = 25;

function noop() {}              // Used to swallow returned metadata from dynode
function unary(x) { return x; } // Used with `spread` to transform (data, metadata) pairs from dynode into just data

exports.Client = function (options) {
    var dynodeClient = new dynode.Client(options);

    var dynodeClientGetItem = Q.nbind(dynodeClient.getItem, dynodeClient);
    var dynodeClientPutItem = Q.nbind(dynodeClient.putItem, dynodeClient);
    var dynodeClientDeleteItem = Q.nbind(dynodeClient.deleteItem, dynodeClient);
    var dynodeClientUpdateItem = Q.nbind(dynodeClient.updateItem, dynodeClient);
    var dynodeClientScan = Q.nbind(dynodeClient.scan, dynodeClient);
    var dynodeClientQuery = Q.nbind(dynodeClient.query, dynodeClient);
    var dynodeClientBatchWriteItem = Q.nbind(dynodeClient.batchWriteItem, dynodeClient);

    return {
        get: function (table, key) {
            return dynodeClientGetItem(table, key).spread(unary);
        },
        put: function (table, values) {
            return dynodeClientPutItem(table, values).then(noop);
        },
        delete: function (table, key) {
            return dynodeClientDeleteItem(table, key).then(noop);
        },
        update: function (table, key, values) {
            return dynodeClientUpdateItem(table, key, values).then(noop);
        },
        updateAndGet: function (table, key, values) {
            return dynodeClientUpdateItem(table, key, values, { ReturnValues: "ALL_NEW" }).get("Attributes");
        },
        query: function (table, hash) {
            return dynodeClientQuery(table, hash).get("Items");
        },
        scan: function (table, options) {
            return dynodeClientScan(table, options).spread(unary);
        },
        deleteMultiple: function (table, keys) {
            var batches = [];
            for (var start = 0; start < keys.length; start += BATCH_MAX_SIZE) {
                batches.push(keys.slice(start, start + BATCH_MAX_SIZE));
            }

            var deletePromises = batches.map(function (batch) {
                var writes = {};
                writes[table] = batch.map(function (key) { return { del: key }; });

                return dynodeClientBatchWriteItem(writes);
            });

            return Q.allResolved(deletePromises).then(function (resultPromises) {
                var rejectedPromises = resultPromises.filter(function (promise) { return promise.isRejected(); });

                if (rejectedPromises.length > 0) {
                    var error = new Error(rejectedPromises.length + "/" + deletePromises.length +
                                          " of the delete batches failed!");
                    error.errors = rejectedPromises.map(function (promise) { return promise.valueOf().exception; });
                    throw error;
                }
            });
        },
    };
};
