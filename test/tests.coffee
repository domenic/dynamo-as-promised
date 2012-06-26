"use strict"

sinon = require("sinon")
Q = require("Q")
sandboxedModule = require("sandboxed-module")

describe "Client", ->
    dynodeClient = {}
    { Client } = sandboxedModule.require(
        "..",
        requires: { dynode: Client: sinon.spy(-> dynodeClient) },
        globals: { Error: Error }
    )

    client = null
    options = { accessKeyId: "AWSAccessKey", secretAccessKey: "SecretAccessKey" }

    tableName = "tableName"
    key = { hash: "hashValue" }
    hashAndRangeKey = { hash: "hashValue", range: 5 }
    stringKey = "hashValue"
    keys = ({ hash: i } for i in [1..54])
    values = { foo: "bar" }
    scanOptions =
        ScanFilter:
            foo:
                AttributeValueList: [{ "S": "bar" }]
                ComparisonOperator: "EQ"

    beforeEach ->
        dynodeClient.getItem = sinon.stub().yields(null, null, {})
        dynodeClient.putItem = sinon.stub().yields(null, null)
        dynodeClient.deleteItem = sinon.stub().yields(null, null)
        dynodeClient.updateItem = sinon.stub().yields(null, {})
        dynodeClient.scan = sinon.stub().yields(null, null, {})
        dynodeClient.query = sinon.stub().yields(null, {})
        dynodeClient.batchWriteItem = sinon.stub().yields(null, null, {})

        client = new Client(options)

    assertCallsCorrectly = (promiseGetter, dynodeMethod, args...) ->
        it "should call `dynodeClient.#{dynodeMethod}` with appropriate context and arguments", (done) ->
            promiseGetter().then(->
                dynodeClient[dynodeMethod].should.have.been.calledOn(dynodeClient)
                dynodeClient[dynodeMethod].should.have.been.calledWith(args...)
            ).should.notify(done)

    assertFailsCorrectly = (promiseGetter, dynodeMethod) ->
        describe "when `dynodeClient.#{dynodeMethod}` fails", ->
            error = new Error()

            beforeEach -> dynodeClient[dynodeMethod].yields(error)

            it "should reject with that error", (done) ->
                promiseGetter().should.be.rejected.with(error).notify(done)


    describe "get", ->
        doIt = -> client.get(tableName, key)

        assertCallsCorrectly(doIt, "getItem", tableName, key)

        describe "when `dynodeClient.getItem` succeeds", ->
            result = { baz: "quux" }

            beforeEach -> dynodeClient.getItem.yields(null, result, {})

            it "should fulfill with the result", (done) ->
                doIt().should.become(result).notify(done)

        assertFailsCorrectly(doIt, "getItem")

    describe "put", ->
        doIt = -> client.put(tableName, values)

        assertCallsCorrectly(doIt, "putItem", tableName, values)

        describe "when `dynodeClient.putItem` succeeds", ->
            beforeEach -> dynodeClient.putItem.yields(null, {})

            it "should fulfill with `undefined`", (done) ->
                doIt().should.become(undefined).notify(done)

        assertFailsCorrectly(doIt, "putItem")

    describe "delete", ->
        doIt = -> client.delete(tableName, values)

        assertCallsCorrectly(doIt, "deleteItem", tableName, values)

        describe "when `dynodeClient.deleteItem` succeeds", ->
            beforeEach -> dynodeClient.deleteItem.yields(null, {})

            it "should fulfill with `undefined`", (done) ->
                doIt().should.become(undefined).notify(done)

        assertFailsCorrectly(doIt, "deleteItem");

    describe "update", ->
        doIt = -> client.update(tableName, key, values)

        assertCallsCorrectly(doIt, "updateItem", tableName, key, values)

        describe "when `dynodeClient.updateItem` succeeds", ->
            beforeEach -> dynodeClient.updateItem.yields(null, {})

            it "should fulfill with `undefined`", (done) ->
                doIt().should.become(undefined).notify(done)

        assertFailsCorrectly(doIt, "updateItem")

        describe "with onlyIfExists option", ->
            describe "and a string for the key parameter", ->
                doIt = -> client.update(tableName, stringKey, values, { onlyIfExists: "hashKey" })

                assertCallsCorrectly(doIt, "updateItem", tableName, stringKey, values, {
                    Expected: hashKey: Value: S: "hashValue"
                })

            describe "and an object with a `hash` property for the key parameter", ->
                doIt = -> client.update(tableName, key, values, { onlyIfExists: { hash: "hashKey" } })

                assertCallsCorrectly(doIt, "updateItem", tableName, key, values, {
                    Expected: hashKey: Value: S: "hashValue"
                })

            describe "and an object with `hash` and `range` properties for the key parameter", ->
                doIt = ->
                    client.update(
                        tableName, hashAndRangeKey, values,
                        { onlyIfExists: { hash: "hashKey", range: "rangeKey" } }
                    )

                assertCallsCorrectly(doIt, "updateItem", tableName, hashAndRangeKey, values, {
                    Expected:
                        hashKey: Value: S: "hashValue"
                        rangeKey: Value: N: "5"
                })

    describe "updateAndGet", ->
        doIt = -> client.updateAndGet(tableName, key, values)

        assertCallsCorrectly(doIt, "updateItem", tableName, key, values, { ReturnValues: "ALL_NEW" })

        describe "when `dynodeClient.updateItem` succeeds", ->
            beforeEach -> dynodeClient.updateItem.yields(
                null,
                Attributes:
                    foo: "x", bar: "baz"
                ConsumedCapacityUnits: 1
            )

            it "should fulfill with the results", (done) ->
                doIt().should.become(foo: "x", bar: "baz").notify(done)

        assertFailsCorrectly(doIt, "updateItem")

        describe "with onlyIfExists option", ->
            describe "and a string for the key parameter", ->
                doIt = -> client.updateAndGet(tableName, stringKey, values, { onlyIfExists: "hashKey" })

                assertCallsCorrectly(doIt, "updateItem", tableName, stringKey, values, {
                    ReturnValues: "ALL_NEW"
                    Expected: hashKey: Value: S: "hashValue"
                })

            describe "and an object with a `hash` property for the key parameter", ->
                doIt = -> client.updateAndGet(tableName, key, values, { onlyIfExists: { hash: "hashKey" } })

                assertCallsCorrectly(doIt, "updateItem", tableName, key, values, {
                    ReturnValues: "ALL_NEW"
                    Expected: hashKey: Value: S: "hashValue"
                })

            describe "and an object with `hash` and `range` properties for the key parameter", ->
                doIt = ->
                    client.updateAndGet(
                        tableName, hashAndRangeKey, values,
                        { onlyIfExists: { hash: "hashKey", range: "rangeKey" } }
                    )

                assertCallsCorrectly(doIt, "updateItem", tableName, hashAndRangeKey, values, {
                    ReturnValues: "ALL_NEW"
                    Expected:
                        hashKey: Value: S: "hashValue"
                        rangeKey: Value: N: "5"
                })

    describe "query", ->
        doIt = -> client.query(tableName, key.hash)

        assertCallsCorrectly(doIt, "query", tableName, key.hash)

        describe "when `dynodeClient.query` succeeds", ->
            items = [{ baz: "quux" }]
            result =
                Count: 1
                Items: items
                ConsumedCapacityUnits: 1

            beforeEach -> dynodeClient.query.yields(null, result)

            it "should fulfill with the array of results", (done) ->
                doIt().should.become(items).notify(done)

        assertFailsCorrectly(doIt, "query")

    describe "scan", ->
        doIt = -> client.scan(tableName, scanOptions)

        assertCallsCorrectly(doIt, "scan", tableName, scanOptions)

        describe "when `dynodeClient.scan` succeeds", ->
            result = [{ baz: "quux" }]

            beforeEach -> dynodeClient.scan.yields(null, result, {})

            it "should fulfill with the array of results", (done) ->
                doIt().should.become(result).notify(done)

        assertFailsCorrectly(doIt, "scan")

    describe "deleteMultiple", ->
        doIt = -> client.deleteMultiple(tableName, keys)

        [batch1, batch2, batch3] = [{}, {}, {}]
        batch1[tableName] = ({ del: hash: i } for i in [1..25])
        batch2[tableName] = ({ del: hash: i } for i in [26..50])
        batch3[tableName] = ({ del: hash: i } for i in [51..54])

        it "should call `dynodeClient.batchWriteItem` for 25 key at a time", (done) ->
            doIt().then(->
                dynodeClient.batchWriteItem.should.have.been.calledThrice
                dynodeClient.batchWriteItem.should.always.have.been.calledOn(dynodeClient)
                dynodeClient.batchWriteItem.should.have.been.calledWith(batch1)
                dynodeClient.batchWriteItem.should.have.been.calledWith(batch2)
                dynodeClient.batchWriteItem.should.have.been.calledWith(batch3)
            ).should.notify(done)

        describe "when `dynodeClient.batchWriteItem` succeeds every time", ->
            beforeEach -> dynodeClient.batchWriteItem.yields(null, null, {})

            it "should fulfill with `undefined`", (done) ->
                doIt().should.become(undefined).notify(done)

        describe "when `dynodeClient.batchWriteItem` fails every time", ->
            beforeEach -> dynodeClient.batchWriteItem.yields(new Error("boo"), null, null)

            it "should reject, mentioning that all batches failed", (done) ->
                doIt().should.be.rejected.with("3/3").notify(done)

            it "should have an errors property on the rejection with the failures", (done) ->
                doIt().fail((err) ->
                    err.should.have.property("errors")
                    err.errors.should.deep.equal([new Error("boo"), new Error("boo"), new Error("boo")])
                ).should.notify(done)

        describe "when `dynodeClient.batchWriteItem` fails once out of three times", ->
            counter = 0

            beforeEach -> dynodeClient.batchWriteItem.withArgs(batch1).yields(new Error("aaah"), null, null)
                                                     .withArgs(batch2).yields(null, null, {})
                                                     .withArgs(batch3).yields(null, null, {})

            it "should reject, mentioning that 1/3 batches failed", (done) ->
                doIt().should.be.rejected.with("1/3").notify(done)

            it "should have an errors property on the rejection with the failure", (done) ->
                doIt().fail((err) ->
                    err.should.have.property("errors")
                    err.errors.should.deep.equal([new Error("aaah")])
                ).should.notify(done)


    describe "table", ->
        table = null

        beforeEach ->
            table = client.table(tableName)

        for method in ["get", "put", "delete", "update", "updateAndGet", "query", "scan", "deleteMultiple"]
            describe "when calling #{method} on the generated table", ->
                beforeEach ->
                    client[method] = sinon.stub().returns(Q.resolve())

                it "should #{method} on its parent client with the correct table name", (done) ->
                    table[method]("a", "b", 1, 2).then(->
                        client[method].should.have.been.calledWithExactly(tableName, "a", "b", 1, 2)
                    ).should.notify(done)
