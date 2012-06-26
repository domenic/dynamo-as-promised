"use strict";

var dynode = require("dynode");
var addDynamoTypeAnnotations = require("dynode/lib/dynode/types").stringify;
var Q = require("q");
var _ = require("underscore");

// See http://docs.amazonwebservices.com/amazondynamodb/latest/developerguide/API_BatchWriteItem.html
var BATCH_MAX_SIZE = 25;

function noop() {}              // Used to swallow returned metadata from dynode
function unary(x) { return x; } // Used with `spread` to transform (data, metadata) pairs from dynode into just data

function createDynodeOptions(dynamoAsPromisedOptions, key, extraDynodeOptions) {
    var dynodeOptions = _.clone(extraDynodeOptions || {});

    // If given an `onlyIfExists` option, assemble the `Expected` Dynode option value by looking at the key and values.
    // Example:
    //     var key = { hash: "H", range: 5 };
    //     var dapOptions = { onlyIfExists: { hash: "h", range: "r" } };
    //     createDynodeOptions(dapOptions, key) === {
    //         Expected: { h: { Value: { S: "H" }, r: { Value: { N: 5 } } }
    //     };
    if (typeof dynamoAsPromisedOptions === "object" && dynamoAsPromisedOptions.onlyIfExists) {
        dynodeOptions.Expected = {};

        var keyValues = typeof key === "string" ? { hash: key } : key;
        var keysThatMustExist = typeof dynamoAsPromisedOptions.onlyIfExists === "string" ?
                                    { hash: dynamoAsPromisedOptions.onlyIfExists } :
                                    dynamoAsPromisedOptions.onlyIfExists;
        Object.keys(keysThatMustExist).forEach(function (keyType) {
            var keyName = keysThatMustExist[keyType];
            var beforeTypeAnnotations = {};
            beforeTypeAnnotations[keyName] = keyValues[keyType];
            var withTypeAnnotations = addDynamoTypeAnnotations(beforeTypeAnnotations);
            dynodeOptions.Expected[keyName] = { Value: withTypeAnnotations[keyName] };
        });
    }

    return dynodeOptions;
}

exports.Client = function (options) {
    var that = this;

    var dynodeClient = new dynode.Client(options);

    var dynodeClientGetItem = Q.nbind(dynodeClient.getItem, dynodeClient);
    var dynodeClientPutItem = Q.nbind(dynodeClient.putItem, dynodeClient);
    var dynodeClientDeleteItem = Q.nbind(dynodeClient.deleteItem, dynodeClient);
    var dynodeClientUpdateItem = Q.nbind(dynodeClient.updateItem, dynodeClient);
    var dynodeClientScan = Q.nbind(dynodeClient.scan, dynodeClient);
    var dynodeClientQuery = Q.nbind(dynodeClient.query, dynodeClient);
    var dynodeClientBatchWriteItem = Q.nbind(dynodeClient.batchWriteItem, dynodeClient);

    that.get = function (table, key) {
        return dynodeClientGetItem(table, key).spread(unary);
    };

    that.put = function (table, values) {
        return dynodeClientPutItem(table, values).then(noop);
    };

    that.delete = function (table, key) {
        return dynodeClientDeleteItem(table, key).then(noop);
    };

    that.update = function (table, key, values, options) {
        var dynodeOptions = createDynodeOptions(options, key);

        return dynodeClientUpdateItem(table, key, values, dynodeOptions).then(noop);
    };

    that.updateAndGet = function (table, key, values, options) {
        var dynodeOptions = createDynodeOptions(options, key, { ReturnValues: "ALL_NEW" });

        return dynodeClientUpdateItem(table, key, values, dynodeOptions).get("Attributes");
    };

    that.query = function (table, hash) {
        return dynodeClientQuery(table, hash).get("Items");
    };

    that.scan = function (table, scanOptions) {
        return dynodeClientScan(table, scanOptions).spread(unary);
    };

    that.deleteMultiple = function (table, keys) {
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
    };

    var methodNames = Object.keys(that);

    that.table = function (table) {
        var tableObj = {};
        methodNames.forEach(function (methodName) {
            tableObj[methodName] = function () {
                return that[methodName].apply(that, [table].concat(Array.prototype.slice.call(arguments)));
            };
        });

        return tableObj;
    };
};
