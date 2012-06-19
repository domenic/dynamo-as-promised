"use strict"

sinon = require("sinon")
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

    table = "table"
    key = { hash: "hash" }
    keys = ({ hash: i } for i in [1..54])
    values = { foo: "bar" }
    query =
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
        doIt = -> client.get(table, key)

        assertCallsCorrectly(doIt, "getItem", table, key)

        describe "when `dynodeClient.getItem` succeeds", ->
            result = { baz: "quux" }

            beforeEach -> dynodeClient.getItem.yields(null, result, {})

            it "should fulfill with the result", (done) ->
                doIt().should.become(result).notify(done)

        assertFailsCorrectly(doIt, "getItem")

    describe "put", ->
        doIt = -> client.put(table, values)

        assertCallsCorrectly(doIt, "putItem", table, values)

        describe "when `dynodeClient.putItem` succeeds", ->
            beforeEach -> dynodeClient.putItem.yields(null, {})

            it "should fulfill with `undefined`", (done) ->
                doIt().should.become(undefined).notify(done)

        assertFailsCorrectly(doIt, "putItem")

    describe "delete", ->
        doIt = -> client.delete(table, values)

        assertCallsCorrectly(doIt, "deleteItem", table, values)

        describe "when `dynodeClient.deleteItem` succeeds", ->
            beforeEach -> dynodeClient.deleteItem.yields(null, {})

            it "should fulfill with `undefined`", (done) ->
                doIt().should.become(undefined).notify(done)

        assertFailsCorrectly(doIt, "deleteItem");

    describe "update", ->
        doIt = -> client.update(table, key, values)

        assertCallsCorrectly(doIt, "updateItem", table, key, values)

        describe "when `dynodeClient.updateItem` succeeds", ->
            beforeEach -> dynodeClient.updateItem.yields(null, {})

            it "should fulfill with `undefined`", (done) ->
                doIt().should.become(undefined).notify(done)

        assertFailsCorrectly(doIt, "updateItem")

    describe "updateAndGet", ->
        doIt = -> client.updateAndGet(table, key, values)

        assertCallsCorrectly(doIt, "updateItem", table, key, values, { ReturnValues: "ALL_NEW" })

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

    describe "scan", ->
        doIt = -> client.scan(table, query)

        assertCallsCorrectly(doIt, "scan", table, query)

        describe "when `dynodeClient.scan` succeeds", ->
            result = [{ baz: "quux" }]

            beforeEach -> dynodeClient.scan.yields(null, result, {})

            it "should fulfill with the array of results", (done) ->
                doIt().should.become(result).notify(done)

        assertFailsCorrectly(doIt, "scan")

    describe "deleteMultiple", ->
        doIt = -> client.deleteMultiple(table, keys)

        [batch1, batch2, batch3] = [{}, {}, {}]
        batch1[table] = ({ del: hash: i } for i in [1..25])
        batch2[table] = ({ del: hash: i } for i in [26..50])
        batch3[table] = ({ del: hash: i } for i in [51..54])

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
