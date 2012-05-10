"use strict"

sinon = require("sinon")
sandboxedModule = require("sandboxed-module")

describe "Client", ->
    dynodeClient = {}
    { Client } = sandboxedModule.require("..", requires: dynode: Client: sinon.spy(-> dynodeClient))

    client = null
    options = { accessKeyId: "AWSAccessKey", secretAccessKey: "SecretAccessKey" }

    table = "table"
    keys = { hash: "hash" }
    keysArray = ({ hash: i } for i in [1..54])
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
        dynodeClient.updateItem = sinon.stub().callsArgWith(3, null, null)
        dynodeClient.scan = sinon.stub().yields(null, null, {})
        dynodeClient.batchWriteItem = sinon.stub().callsArgWith(1, null, null, {})

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


    describe "getAsync", ->
        doItAsync = -> client.getAsync(table, keys)

        assertCallsCorrectly(doItAsync, "getItem", table, keys)

        describe "when `dynodeClient.getItem` succeeds", ->
            result = { baz: "quux" }

            beforeEach -> dynodeClient.getItem.yields(null, result, {})

            it "should fulfill with the result", (done) ->
                doItAsync().should.become(result).notify(done)

        assertFailsCorrectly(doItAsync, "getItem")

    describe "putAsync", ->
        doItAsync = -> client.putAsync(table, values)

        assertCallsCorrectly(doItAsync, "putItem", table, values)

        describe "when `dynodeClient.putItem` succeeds", ->
            beforeEach -> dynodeClient.putItem.yields(null, {})

            it "should fulfill with `undefined`", (done) ->
                doItAsync().should.become(undefined).notify(done)

        assertFailsCorrectly(doItAsync, "putItem")

    describe "deleteAsync", ->
        doItAsync = -> client.deleteAsync(table, values)

        assertCallsCorrectly(doItAsync, "deleteItem", table, values)

        describe "when `dynodeClient.deleteItem` succeeds", ->
            beforeEach -> dynodeClient.deleteItem.yields(null, {})

            it "should fulfill with `undefined`", (done) ->
                doItAsync().should.become(undefined).notify(done)

        assertFailsCorrectly(doItAsync, "deleteItem");

    describe "updateAsync", ->
        doItAsync = -> client.updateAsync(table, keys, values)

        assertCallsCorrectly(doItAsync, "updateItem", table, keys, values)

        describe "when `dynodeClient.updateItem` succeeds", ->
            beforeEach -> dynodeClient.updateItem.yields(null, {})

            it "should fulfill with `undefined`", (done) ->
                doItAsync().should.become(undefined).notify(done)

        assertFailsCorrectly(doItAsync, "updateItem")

    describe "scanAsync", ->
        doItAsync = -> client.scanAsync(table, query)

        assertCallsCorrectly(doItAsync, "scan", table, query)

        describe "when `dynodeClient.scan` succeeds", ->
            result = [{ baz: "quux" }]

            beforeEach -> dynodeClient.scan.yields(null, result, {})

            it "should fulfill with the array of results", (done) ->
                doItAsync().should.become(result).notify(done)

        assertFailsCorrectly(doItAsync, "scan")

    describe "deleteMultipleAsync", ->
        doItAsync = -> client.deleteMultipleAsync(table, keysArray)

        [batch1, batch2, batch3] = [{}, {}, {}]
        batch1[table] = ({ del: hash: i } for i in [1..25])
        batch2[table] = ({ del: hash: i } for i in [26..50])
        batch3[table] = ({ del: hash: i } for i in [51..54])

        it "should call `dynodeClient.batchWriteItem` for 25 keys at a time", (done) ->
            doItAsync().then(->
                dynodeClient.batchWriteItem.should.have.been.calledThrice
                dynodeClient.batchWriteItem.should.always.have.been.calledOn(dynodeClient)
                dynodeClient.batchWriteItem.should.have.been.calledWith(batch1)
                dynodeClient.batchWriteItem.should.have.been.calledWith(batch2)
                dynodeClient.batchWriteItem.should.have.been.calledWith(batch3)
            ).should.notify(done)

        describe "when `dynodeClient.batchWriteItem` succeeds every time", ->
            beforeEach -> dynodeClient.batchWriteItem.yields(null, null, {})

            it "should fulfill with `undefined`", (done) ->
                doItAsync().should.become(undefined).notify(done)

        describe "when `dynodeClient.batchWriteItem` fails every time", ->
            beforeEach -> dynodeClient.batchWriteItem.yields(new Error(), null, null)

            it "should reject, mentioning that all batches failed", (done) ->
                doItAsync().should.be.rejected.with("3/3").notify(done)

        describe "when `dynodeClient.batchWriteItem` fails once out of three times", ->
            counter = 0

            beforeEach -> dynodeClient.batchWriteItem.withArgs(batch1).yields(new Error(), null, null)
                                                     .withArgs(batch2).yields(null, null, {})
                                                     .withArgs(batch3).yields(null, null, {})

            it "should reject, mentioning that 1/3 batches failed", (done) ->
                doItAsync().should.be.rejected.with("1/3").notify(done)
