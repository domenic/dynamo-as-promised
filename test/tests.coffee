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

    error = null

    beforeEach ->
        dynodeClient.getItem = sinon.stub().callsArgWith(2, null, null, {})
        dynodeClient.putItem = sinon.stub().callsArgWith(2, null, null)
        dynodeClient.deleteItem = sinon.stub().callsArgWith(2, null, null)
        dynodeClient.updateItem = sinon.stub().callsArgWith(3, null, null)
        dynodeClient.scan = sinon.stub().callsArgWith(2, null, null, {})
        dynodeClient.batchWriteItem = sinon.stub().callsArgWith(1, null, null, {})

        client = new Client(options)

    assertFailsCorrectly = (promiseGetter, dynodeMethod) ->
        describe "when `dynodeClient." + dynodeMethod + "` fails", ->
            error = null

            beforeEach ->
                error = new Error()
                error.name = "AmazonError"
                error.statusCode = 400
                error.message = "boo!"

                errorArgPosition = switch dynodeMethod
                    when "updateItem" then 3
                    when "batchWriteItem" then 1
                    else 2
                dynodeClient[dynodeMethod].callsArgWith(errorArgPosition, error)

            it "should reject with that error", (done) ->
                promiseGetter().should.be.rejected.with(error).notify(done)


    describe "getAsync", ->
        doItAsync = -> client.getAsync(table, keys)

        it "should call `dynodeClient.getItem` with appropriate context and arguments", (done) ->
            doItAsync().then(->
                dynodeClient.getItem.should.have.been.calledOn(dynodeClient)
                dynodeClient.getItem.should.have.been.calledWith(table, keys)
            ).should.notify(done)

        describe "when `dynodeClient.getItem` succeeds", ->
            result = { baz: "quux" }

            beforeEach -> dynodeClient.getItem.callsArgWith(2, null, result, {})

            it "should fulfill with the result", (done) ->
                doItAsync().should.become(result).notify(done)

        assertFailsCorrectly(doItAsync, "getItem")

    describe "putAsync", ->
        doItAsync = -> client.putAsync(table, values)

        it "should call `dynodeClient.putItem` with appropriate context and arguments", (done) ->
            doItAsync().then(->
                dynodeClient.putItem.should.have.been.calledOn(dynodeClient)
                dynodeClient.putItem.should.have.been.calledWith(table, values)
            ).should.notify(done)

        describe "when `dynodeClient.putItem` succeeds", ->
            beforeEach -> dynodeClient.putItem.callsArgWith(2, null, {})

            it "should fulfill with `undefined`", (done) ->
                doItAsync().should.become(undefined).notify(done)

        assertFailsCorrectly(doItAsync, "putItem")

    describe "deleteAsync", ->
        doItAsync = -> client.deleteAsync(table, values)

        it "should call `dynodeClient.deleteItem` with appropriate context and arguments", (done) ->
            doItAsync().then(->
                dynodeClient.deleteItem.should.have.been.calledOn(dynodeClient)
                dynodeClient.deleteItem.should.have.been.calledWith(table, values)
            ).should.notify(done)

        describe "when `dynodeClient.deleteItem` succeeds", ->
            beforeEach -> dynodeClient.deleteItem.callsArgWith(2, null, {})

            it "should fulfill with `undefined`", (done) ->
                doItAsync().should.become(undefined).notify(done)

        assertFailsCorrectly(doItAsync, "deleteItem");

    describe "updateAsync", ->
        doItAsync = -> client.updateAsync(table, keys, values)

        it "should call `dynodeClient.updateItem` with appropriate context and arguments", (done) ->
            doItAsync().then(->
                dynodeClient.updateItem.should.have.been.calledOn(dynodeClient)
                dynodeClient.updateItem.should.have.been.calledWith(table, keys, values)
            ).should.notify(done)

        describe "when `dynodeClient.updateItem` succeeds", ->
            beforeEach -> dynodeClient.updateItem.callsArgWith(3, null, {})

            it "should fulfill with `undefined`", (done) ->
                doItAsync().should.become(undefined).notify(done)

        assertFailsCorrectly(doItAsync, "updateItem")

    describe "scanAsync", ->
        doItAsync = -> client.scanAsync(table, query)

        it "should call `dynodeClient.scan` with appropriate context and arguments", (done) ->
            doItAsync().then(->
                dynodeClient.scan.should.have.been.calledOn(dynodeClient)
                dynodeClient.scan.should.have.been.calledWith(table, query)
            ).should.notify(done)

        describe "when `dynodeClient.scan` succeeds", ->
            result = [{ baz: "quux" }]

            beforeEach -> dynodeClient.scan.callsArgWith(2, null, result, {})

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
            beforeEach -> dynodeClient.batchWriteItem.callsArgWith(1, null, null, {})

            it "should fulfill with `undefined`", (done) ->
                doItAsync().should.become(undefined).notify(done)

        describe "when `dynodeClient.batchWriteItem` fails every time", ->
            beforeEach -> dynodeClient.batchWriteItem.callsArgWith(1, new Error(), null, null)

            it "should reject, mentioning that all batches failed", (done) ->
                doItAsync().should.be.rejected.with("3/3").notify(done)

        describe "when `dynodeClient.batchWriteItem` fails once out of three times", ->
            counter = 0

            beforeEach -> dynodeClient.batchWriteItem.withArgs(batch1).callsArgWith(1, error, null, null)
                                                     .withArgs(batch2).callsArgWith(1, null, null, {})
                                                     .withArgs(batch3).callsArgWith(1, null, null, {})

            it "should reject, mentioning that 1/3 batches failed", (done) ->
                doItAsync().should.be.rejected.with("1/3").notify(done)
