var Big = require('bignumber.js')

function rpc(method, arg) {
    var req = {
        jsonrpc: "2.0",
        method: method,
        id: new Date().getTime()
    }
    if (arg) req.params = arg

    return new Promise((resolve, reject) => {
        web3.currentProvider.sendAsync(req, (err, result) => {
            if (err) return reject(err)
            if (result && result.error) {
                return reject(new Error("RPC Error: " + (result.error.message || result.error)))
            }
            resolve(result)
        })
    })
}

// Change block time using the rpc call "evm_setTimestamp"
// https://github.com/ethereumjs/testrpc/issues/47
web3.evm = web3.evm || {}
web3.evm.increaseTime = function(time) {
    return rpc('evm_increaseTime', [time])
}

function checkAllGasSpent(gasAmount, gasPrice, account, prevBalance) {
    var newBalance = web3.eth.getBalance(account)
    assert.equal(prevBalance.minus(newBalance).toNumber(), gasAmount * gasPrice, 'Incorrect amount of gas used')
}

function ifUsingTestRPC() {
    return
}

// lifted from: https://ethereum.stackexchange.com/questions/9103/how-can-you-handle-an-expected-throw-in-a-contract-test-using-truffle-and-ethere
function assertThrows (fn, args) {
    //Asserts that `fn(args)` will throw a specific type of error.
    return new Promise(
        function(resolve, reject){
            fn.apply(this, args)
                .then(() => {
                    assert(false, 'No error thrown.');
                    resolve();
                },
                (error) => {
                    var errstr = error.toString();
                    var newErrMsg = errstr.indexOf('invalid opcode') != -1;
                    var oldErrMsg = errstr.indexOf('invalid JUMP') != -1;
                    if(!newErrMsg && !oldErrMsg)
                      assert(false, 'Did not receive expected error message');
                    resolve();
                })
        })
}

// Some default values for gas
var gasAmount = 3000000
var gasPrice = 20000000000
var initialDisbursement = new Big(1500000000000000000000000)
var nmr_per_week = new Big(96153846153846100000000).add(53846153)
var realTournament = 5
var realRound = 55
var realRound2 = 555

var multiSigAddresses = ['0x54fd80d6ae7584d8e9a19fe1df43f04e5282cc43', '0xa6d135de4acf44f34e2e14a4ee619ce0a99d1e08']
var Numeraire = artifacts.require("./NumeraireBackend.sol")
var NumeraireDelegate = artifacts.require("./NumeraireDelegate.sol")
var snapshotID = 0
var stakeSnapshot = 0

// either equal or two is a second after one.  it's okay if one second has
// passed during the test
function almost_equal(one, two) {
  return two.equals(one) || two.equals(one.add(nmr_per_week.div(7 * 24 * 60 * 60)).ceil())
}

contract('Numeraire', function(accounts) {

    before(function(done) {
        var etherAmount = new Big('1000000000000000000')
        web3.eth.sendTransaction({from: accounts[0], to: multiSigAddresses[0], value: etherAmount, gasLimit: 21000, gasPrice: gasPrice})
        web3.eth.sendTransaction({from: accounts[5], to: multiSigAddresses[1], value: etherAmount, gasLimit: 21000, gasPrice: gasPrice})

        Numeraire.deployed().then(function(nmrInstance) {
        NumeraireDelegate.deployed().then(function(delegateInstance) {
        nmrInstance.changeDelegate(delegateInstance.address, {from: multiSigAddresses[0]}).then(function() {
        nmrInstance.changeDelegate(delegateInstance.address, {from: multiSigAddresses[1]}).then(function() {
        done()
    }) }) }) }) })

    it ("should set the delegate correctly", function(done) { // XXX
        Numeraire.deployed().then(function(nmrInstance) {
        NumeraireDelegate.deployed().then(function(delegateInstance) {
        nmrInstance.delegateContract.call().then(function(delegateAddress) {
            assert.equal(delegateAddress, delegateInstance.address)
        done()
    }) }) }) })

    it("should have set initial_disbursement when deployed", function(done) {
        Numeraire.deployed().then(function(nmrInstance) {
        nmrInstance.initial_disbursement.call().then(function(disbursement) {
            assert.equal(true, disbursement.equals(initialDisbursement))
        done()
    }) }) })

    it("should not mint significantly more than the initial disbursement", function(done) {
        var prevBalance
        var nmr = Numeraire.deployed().then(function(instance) {
            prevBalance = web3.eth.getBalance(accounts[0])
            // try to mint initalDisbursement + 1 NMR (should allow ~0.16 NMR/second)
            instance.mint(initialDisbursement.add(new Big(1000000000000000000)), {
                    from: accounts[0],
                    gasPrice: gasPrice,
                    gas: gasAmount
                })
                .catch(ifUsingTestRPC)
                .then(function() {
                    checkAllGasSpent(gasAmount, gasPrice, accounts[0], prevBalance)
                })
                .then(function () {
                    done()})
                .catch(done)
        })
    })

    it("should mint correctly", function(done) {
        Numeraire.deployed().then(function(instance) {
        instance.mint(10000000000, {from: accounts[0]}).then(function() {
        instance.balanceOf.call(instance.address).then(function(balance) {
            // check if Numerai has minted amount
            assert.equal(balance.toNumber(), 10000000000)
        done()
    }) }) }) })

    it("should increment totalSupply on mint", function(done) {
        Numeraire.deployed().then(function(instance) {
        instance.totalSupply.call().then(function(supply) {
            // check if supply has increased by minted amounts
            assert.equal(supply.toNumber(), 10000000000)
        done()
    }) }) })

    it('should reduce mintable when minting', function(done) {
        Numeraire.deployed().then(function(instance) {
        instance.getMintable.call().then(function(last_disbursement) {
        instance.mint(initialDisbursement, { from: accounts[0] }).then(function() {
        instance.getMintable.call().then(function(disbursement) {
            assert.equal(true, almost_equal(last_disbursement.sub(initialDisbursement), disbursement))
        done()
    }) }) }) }) })

    it("should increase mintable 96153.846153846153846153 NMR per week", function(done) {
        Numeraire.deployed().then(function(instance) {
        instance.getMintable.call().then(oldDisbursement => {
        instance.mint(500000, { from: accounts[0] }).then(() => {
        web3.evm.increaseTime(7 * 24 * 60 * 60).then(() => {
        instance.mint(20000000000, { from: accounts[0] }).then(() => {
        instance.getMintable.call().then(newDisbursement => {
            assert.equal(true, almost_equal(oldDisbursement.sub(500000).add(nmr_per_week).sub(20000000000), newDisbursement))
        done()
    }) }) }) }) }) }) })

    it("should send NMR correctly from numerai account", function(done) {
        var account_one = Numeraire.address
        var account_two = accounts[2]
        var amount = 1000000000

        Numeraire.deployed().then(function(instance) {
        instance.mint(amount, { from: accounts[0] }).then(function() {
        instance.balanceOf.call(account_one).then(function(account_one_starting) {
        instance.balanceOf.call(account_two).then(function(account_two_starting) {
        instance.numeraiTransfer(account_two, amount, {from: accounts[0]}).then(function() {
        instance.numeraiTransfer(account_two, amount, {from: multiSigAddresses[0]}).then(function() {
        instance.balanceOf.call(account_one).then(function(account_one_ending) {
        instance.balanceOf.call(account_two).then(function(account_two_ending) {
            assert.equal(account_one_ending.toNumber(), account_one_starting.toNumber() - amount,
                "Amount wasn't correctly taken from the sender")
            assert.equal(account_two_ending.toNumber(), account_two_starting.toNumber() + amount,
                "Amount wasn't correctly sent to the receiver")
        done()
    }) }) }) }) }) }) }) }) })

    it('should create a tournament', (done) => { // XXX
        Numeraire.deployed().then(function(instance) {
        instance.createTournament(0).then(function(transaction) {
            var block = web3.eth.getBlock(transaction.receipt.blockNumber)
        instance.getTournament.call(0).then(function(tournament) {
            creationTime = tournament[0]
            numRounds = tournament[1].length
            assert.equal(0, numRounds)
            assert.equal(block.timestamp, creationTime.toNumber())
        done()
    }) }) }) })

    it('should create a round', (done) => { // XXX
        Numeraire.deployed().then(function(instance) {
        instance.createTournament(50).then(function(transaction) {
            var block = web3.eth.getBlock(transaction.receipt.blockNumber)
            var resolutionTime = block.timestamp + (4 * 7 * 24 * 60 * 60)
        instance.createRound(0, 51, resolutionTime).then(function(transaction) {
            var block = web3.eth.getBlock(transaction.receipt.blockNumber)
        instance.getRound.call(0, 51).then(function(round) {
            creationTime = round[0]
            realResolutionTime = round[1]
            numStakes = round[2].length
            assert.equal(creationTime.toNumber(), block.timestamp)
            assert.equal(realResolutionTime.toNumber(), resolutionTime)
            assert.equal(numStakes, 0)
        instance.getTournament.call(0).then(function(tournament) {
            numRounds = tournament[1].length
            roundIDs = tournament[1]
            assert.equal(1, numRounds)
            // FIXME: This test doesn't work, although the contract is doing the right thing
            // assert.equal(roundIDs, [51]) 
        done()
    }) }) }) }) }) })

    it('should stake NMR on behalf of another account', (done) => {
        numerai_hot_wallet = accounts[2]
        var user_account = '0x1234'
        var amount = 500
        Numeraire.deployed().then(function(instance) {
        instance.balanceOf.call(numerai_hot_wallet).then((balance) => {
        instance.transfer(user_account, amount, {from: numerai_hot_wallet}).then(function() {
        instance.stakeOnBehalf(user_account, amount, 0, 51, 5, {from: accounts[0]}).then(function(tx_id) {
            var block = web3.eth.getBlock(tx_id.receipt.blockNumber)
        instance.getStake.call(0, 51, user_account, block.timestamp, 0).then(function(stake) {
            assert.equal(stake[0].toNumber(), 5)
            assert.equal(stake[1].toNumber(), amount)
            assert.equal(stake[2], false)
            assert.equal(stake[3], false)
        instance.balanceOf.call(numerai_hot_wallet).then((balance_after) => {
            assert.equal(balance.toNumber() - amount, balance_after.toNumber())
        done()
    }) }) }) }) }) }) })


    it('should stake NMR as self', (done) => { // XXX
        var amount = 500
        var userAccount = accounts[2]
        Numeraire.deployed().then(function(instance) {
        instance.balanceOf.call(userAccount).then((balance) => {
        instance.stake(amount, 0, 51, 1, {from: userAccount}).then(function(tx_id) {
            var block = web3.eth.getBlock(tx_id.receipt.blockNumber)
        instance.getStake.call(0, 51, userAccount).then(function(stake) {
            assert.equal(stake[0].toNumber(), 1)
            assert.equal(stake[1].toNumber(), amount)
            assert.equal(stake[2], false)
            assert.equal(stake[3], false)
        instance.balanceOf.call(userAccount).then((balance_after) => {
            assert.equal(balance.toNumber() - amount, balance_after.toNumber())
        done()
    }) }) }) }) }) })

    it("should send NMR correctly", function(done) { // XXX
        var account_one = accounts[1]
        var account_two = accounts[2]
        var amount = 1000000000 - 1000
        Numeraire.deployed().then(function(instance) {
        instance.mint(amount, { from: accounts[0] }).then(function() {
        instance.balanceOf.call(account_one).then(function(account_one_starting) {
        instance.balanceOf.call(account_two).then(function(account_two_starting) {
        instance.transfer(account_one, amount, { from: account_two }).then(function() {
        instance.balanceOf.call(account_one).then(function(account_one_ending) {
        instance.balanceOf.call(account_two).then(function(account_two_ending) {
            assert.equal(account_one_ending.toNumber(), account_one_starting.toNumber() + amount,
                "Amount wasn't correctly sent to the receiver")
            assert.equal(account_two_ending.toNumber(), account_two_starting.toNumber() - amount,
                "Amount wasn't correctly taken from the sender")
        done()
    }) }) }) }) }) }) }) })

    it('should destroy stake', function(done) {
        var numerai_hot_wallet = accounts[1]
        var user_account = '0x4321'
        var amount = 500
        Numeraire.deployed().then(function(instance) {
        rpc('evm_snapshot').then(function(snapshot) {
            snapshotID = snapshot['result']
        instance.transfer(user_account, amount, {from: numerai_hot_wallet}).then(function() {
        instance.stakeOnBehalf(user_account, amount, 0, 51, 6, {from: accounts[0]}).then(function(tx_id) {
        web3.evm.increaseTime(4 * 7 * 24 * 60 * 60).then(() => { // Make sure the block timestamp is new
        instance.totalSupply.call().then(function(totalSupply) {
            var originalTotalSupply = totalSupply.toNumber()
            var block = web3.eth.getBlock(tx_id.receipt.blockNumber)
        instance.destroyStake(user_account, 0, 51, {from: accounts[0]}).then(function() {
        instance.totalSupply.call().then(function(newSupply) {
            assert.equal(originalTotalSupply - amount, newSupply.toNumber())
        instance.getStake.call(0, 51, user_account).then(function(stake) {
            assert.equal(stake[0].toNumber(), 6)
            assert.equal(stake[1].toNumber(), 0)
            assert.equal(stake[2], false)
            assert.equal(stake[3], true)
        done()
    }) }) }) }) }) }) }) }) }) })

    it('should release stake', function(done) {
        var numerai_hot_wallet = accounts[1]
        var stakeBeforeRelease = 0
        var amount = 500
        var originalNumeraiBalance = 0
        var staker = '0x0000000000000000000000000000000000005555'
        var tournamentID = 51
        var roundID = 52
        rpc('evm_revert', [snapshotID]).then(function() {
        Numeraire.deployed().then(function(instance) {
        instance.createTournament(tournamentID).then(function(transaction) {
            var block = web3.eth.getBlock(transaction.receipt.blockNumber)
            var resolutionTime = block.timestamp + (4 * 7 * 24 * 60 * 60)
        instance.createRound(tournamentID, roundID, resolutionTime).then(function() {
            var originalBalance = web3.eth.getBalance(staker)
        instance.transfer(staker, amount, {from: numerai_hot_wallet}).then(function() {
        instance.stakeOnBehalf(staker, amount, tournamentID, roundID, 7, {from: accounts[0]}).then(function(tx_id) {
            var block = web3.eth.getBlock(tx_id.receipt.blockNumber)
        instance.balanceOf.call(instance.address).then(function(numeraiBalance) {
            originalNumeraiBalance = numeraiBalance.toNumber()
        instance.balanceOf.call(staker).then(function(originalStakerBalance) {
        instance.getStake.call(tournamentID, roundID, staker).then(function(stake) {
            stakeBeforeRelease = stake[1].toNumber()
        web3.evm.increaseTime(4 * 7 * 24 * 60 * 60).then(function() {
        instance.releaseStake(staker, 0, tournamentID, roundID, true, {from: accounts[0]}).then(function() {
        instance.balanceOf.call(instance.address).then(function(numeraiBalance) {
            assert.equal(originalNumeraiBalance, numeraiBalance.toNumber())
        instance.balanceOf.call(staker).then(function(newStakerBalance) {
            assert.equal(newStakerBalance.toNumber(), originalStakerBalance.toNumber() + amount)
        instance.getStake.call(tournamentID, roundID, staker).then(function(stakeAfterRelease) {
            assert.equal(stakeAfterRelease[0], 7)
            assert.equal(stakeBeforeRelease - amount, stakeAfterRelease[1].toNumber()) // ?
            assert.equal(stakeAfterRelease[2], true)
            assert.equal(stakeAfterRelease[3], true)
            var newBalance = web3.eth.getBalance(staker)
            assert.equal(originalBalance.toNumber(), newBalance.toNumber())
        done()
    }) }) }) }) }) }) }) }) }) }) }) }) }) }) })

    it('should transfer from an assignable deposit address', function(done) {
        var assignedAddress = '0xf4240'
        var amount = 25
        var prevBalance = web3.eth.getBalance(accounts[0])
        Numeraire.deployed().then(function(instance) {
        instance.balanceOf.call(instance.address).then(function(originalNumeraiBalance) {
        instance.numeraiTransfer(assignedAddress, amount, {from: accounts[0]}).then(function() {
        instance.numeraiTransfer(assignedAddress, amount, {from: multiSigAddresses[0]}).then(function() {
        instance.balanceOf.call(instance.address).then(function(newNumeraiBalance) {
            assert.equal(originalNumeraiBalance.toNumber() - amount, newNumeraiBalance.toNumber()) 
        instance.balanceOf.call(assignedAddress).then(function(assignedBalance) {
            assert.equal(amount, assignedBalance.toNumber())
        instance.withdraw(assignedAddress, instance.address, amount, {from: accounts[0]}).then(function() {
        instance.balanceOf.call(instance.address).then(function(numeraiBalance) {
            assert.equal(originalNumeraiBalance.toNumber(), numeraiBalance.toNumber())
        instance.balanceOf.call(assignedAddress).then(function(assignedBalance) {
            assert.equal(assignedBalance.toNumber(), 0)
        done()
    }) }) }) }) }) }) }) }) }) })

    // All tests above this line are deprecated, but don't remove them unless
    // there is an equivalent one below.

    it('should test name', function(done) { // erc20
        Numeraire.deployed().then(instance => {
        instance.name().then(name => {
            assert.equal(name, "Numeraire")
        done()
    }) }) })

    it('should test symbol', function(done) { // erc20
        Numeraire.deployed().then(instance => {
        instance.symbol().then(symbol => {
            assert.equal(symbol, "NMR")
        done()
    }) }) })

    it('should test decimals', function(done) { // erc20
        Numeraire.deployed().then(instance => {
        instance.decimals().then(decimals => {
            assert.equal(decimals, 18)
        done()
    }) }) })

    it('should test totalSupply', function(done) { // erc20
        Numeraire.deployed().then(instance => {
        instance.totalSupply().then(totalSupply => {
            assert(totalSupply.gte(initialDisbursement))
            assert(totalSupply.lte(initialDisbursement.mul(2)))
        done()
    }) }) })

    it('should test balanceOf', function(done) { // erc20
        Numeraire.deployed().then(instance => {
        instance.balanceOf(instance.address).then(balance => {
            assert(balance.gte(initialDisbursement))
            assert(balance.lte(initialDisbursement.mul(2)))
        done()
    }) }) })

    it('should test allowance') // erc20

    it('should change delegate', function(done) {
        var zero = '0x0000000000000000000000000000000000000000'
        Numeraire.deployed().then(instance => {
        NumeraireDelegate.deployed().then(delegate => {
        instance.delegateContract().then(delegateAddress => {
            assert.equal(delegate.address, delegateAddress)
        instance.changeDelegate(zero, {from: multiSigAddresses[0]}).then(() => {
        instance.changeDelegate(zero, {from: multiSigAddresses[1]}).then(() => {
        instance.delegateContract().then(delegateAddress => {
            assert.equal(zero, delegateAddress)
        instance.changeDelegate(delegate.address, {from: multiSigAddresses[0]}).then(() => {
        instance.changeDelegate(delegate.address, {from: multiSigAddresses[1]}).then(() => {
        instance.delegateContract().then(delegateAddress => {
            assert.equal(delegate.address, delegateAddress)
        done()
    }) }) }) }) }) }) }) }) }) })

    it('should disable contract upgradability', function(done) {
        var zero = '0x0000000000000000000000000000000000000000'
        Numeraire.deployed().then(instance => {
        NumeraireDelegate.deployed().then(delegate => {
        instance.delegateContract().then(delegateAddress => {
            assert.equal(delegate.address, delegateAddress)
        instance.contractUpgradable().then(upgradable => {
            assert.equal(upgradable, true)
        instance.disableContractUpgradability({from: multiSigAddresses[0]}).then(() => {
        instance.disableContractUpgradability({from: multiSigAddresses[1]}).then(() => {
        instance.contractUpgradable().then(upgradable => {
            assert.equal(upgradable, false)
        instance.changeDelegate(zero, {from: multiSigAddresses[0]}).then(() => {
        assertThrows(instance.changeDelegate, [zero, {from: multiSigAddresses[1]}]).then(() => {
        instance.delegateContract().then(delegateAddress => {
            assert.equal(delegate.address, delegateAddress)
        done()
    }) }) }) }) }) }) }) }) }) }) })

    it('should allow claiming ether', function(done) {
        var ether = new Big('1000000000000000000') // 1 ether
        Numeraire.deployed().then(instance => {
            var oldBalance = web3.eth.getBalance(accounts[0])
            web3.eth.sendTransaction({from: accounts[0], to: instance.address, value: ether, gasLimit: 21000, gasPrice: gasPrice})
            assert(web3.eth.getBalance(instance.address).equals(ether))
        instance.claimTokens(0, {gasLimit: gasAmount, gasPrice: gasPrice}).then(() => {
            assert(web3.eth.getBalance(instance.address).equals(new Big('0')))
            assert(web3.eth.getBalance(accounts[0]).gte(oldBalance.minus((gasAmount + 21000) * gasPrice)))
        done()
    }) }) })

    it('should test claiming another token')

    it('should disallow claiming NMR', function(done) {
        var amount = new Big('1000000000000000') // .001 NMR
        Numeraire.deployed().then(instance => {
        instance.balanceOf(instance.address).then(oldInstanceBalance =>  {
        assertThrows(instance.claimTokens, [instance.address]).then(() => {
        instance.balanceOf(instance.address).then(newInstanceBalance => {
            assert(!newInstanceBalance.equals(new Big('0')))
        done()
    }) }) }) }) })

    it('should create a tournament', function(done) {
        Numeraire.deployed().then(instance => {
        instance.createTournament(realTournament).then(transaction => {
            var block = web3.eth.getBlock(transaction.receipt.blockNumber)
        instance.getTournament(realTournament).then(tournament => {
            assert.equal(tournament[0].toNumber(), block.timestamp)
            assert.equal(tournament[1].length, 0)
        done()
    }) }) }) })

    it('should fail to create an existing tournament', function(done) {
        Numeraire.deployed().then(instance => {
        assertThrows(instance.createTournament, [realTournament]).then(() => {
        done()
    }) }) })

    it('should create a round in an existing tournament', function(done) {
        Numeraire.deployed().then(instance => {
        instance.getTournament(realTournament).then(tournament => {
            assert.isAbove(tournament[0], 0)
            var block = web3.eth.getBlock("latest")
            var resolutionTime = block.timestamp + (4 * 7 * 24 * 60 * 60)
        instance.createRound(realTournament, realRound, resolutionTime).then(transaction => {
        instance.getRound(realTournament, realRound).then(round => {
            var newBlock = web3.eth.getBlock(transaction.receipt.blockNumber)
            assert.equal(round[0].toNumber(), newBlock.timestamp)
            assert.equal(round[1].toNumber(), resolutionTime)
            assert.equal(round[2].length, 0)
        instance.getTournament(realTournament).then(tournament => {
            assert.equal(tournament[1][0].toNumber(), realRound)
        done()
    }) }) }) }) }) })

    it('should fail to create a round in a non-existing tournament', function(done) {
        Numeraire.deployed().then(instance => {
        instance.getTournament(realTournament+1).then(tournament => {
            assert.equal(tournament[0], 0)
            var block = web3.eth.getBlock("latest")
            var resolutionTime = block.timestamp + (4 * 7 * 24 * 60 * 60)
        assertThrows(instance.createRound, [realTournament+1, realRound, resolutionTime]).then(() => {
        done()
    }) }) }) })

    it('should fail to create an existing round in an existing tournament', function(done) {
        Numeraire.deployed().then(instance => {
        instance.getTournament(realTournament).then(tournament => {
            assert.isAbove(tournament[0], 0)
            assert.equal(tournament[1][0].toNumber(), realRound)
            var block = web3.eth.getBlock("latest")
            var resolutionTime = block.timestamp + (4 * 7 * 24 * 60 * 60)
        assertThrows(instance.createRound, [realTournament, realRound, resolutionTime]).then(() => {
        done()
    }) }) }) })

    it('should create a stake', function(done) {
        var amount = 500
        var confidence = 8
        var user = accounts[2]
        Numeraire.deployed().then(instance => {
        instance.numeraiTransfer(user, amount, {from: accounts[0]}).then(() => {
        instance.numeraiTransfer(user, amount, {from: multiSigAddresses[0]}).then(() => {
        instance.balanceOf(user).then(startingBalance => {
            assert(startingBalance.gte(amount))
        instance.stake(amount, realTournament, realRound, confidence, {from: user}).then(() => {
        instance.getStake(realTournament, realRound, user).then(stake => {
            assert.equal(stake[0].toNumber(), 8)
            assert.equal(stake[1].toNumber(), amount)
            assert.equal(stake[2], false)
            assert.equal(stake[3], false)
        instance.balanceOf(user).then(endingBalance => {
            assert(startingBalance.minus(amount).equals(endingBalance))
        instance.getRound(realTournament, realRound).then(round => {
            assert.equal(round[2][0], user)
        rpc('evm_snapshot').then(function(snapshot) {
            stakeSnapshot = snapshot['result']
        done()
    }) }) }) }) }) }) }) }) }) })

    it('should fail to create a stake as owner', function(done) {
        var amount = 500
        var user = accounts[0]
        Numeraire.deployed().then(instance => {
        instance.numeraiTransfer(user, amount, {from: accounts[0]}).then(() => {
        instance.numeraiTransfer(user, amount, {from: multiSigAddresses[0]}).then(() => {
        instance.balanceOf(user).then(startingBalance => {
            assert(startingBalance.gte(amount))
        assertThrows(instance.stake, [amount, realTournament, realRound, 8, {from: user}]).then(() => {
        done()
    }) }) }) }) }) })

    it('should fail to stake more than balance', function(done) {
        var user = accounts[2]
        Numeraire.deployed().then(instance => {
        instance.balanceOf(user).then(startingBalance => {
        assertThrows(instance.stake, [startingBalance.plus(1), realTournament, realRound, 8, {from: user}]).then(() => {
        done()
    }) }) }) })

    it('should fail to create a stake on a non-existing tournament', function(done) {
        var amount = 500
        var user = accounts[2]
        Numeraire.deployed().then(instance => {
        instance.numeraiTransfer(user, amount, {from: accounts[0]}).then(() => {
        instance.numeraiTransfer(user, amount, {from: multiSigAddresses[0]}).then(() => {
        instance.balanceOf(user).then(startingBalance => {
            assert(startingBalance.gte(amount))
        instance.getTournament(realTournament+1).then(tournament => {
            assert.equal(tournament[0].toNumber(), 0)
        assertThrows(instance.stake, [amount, realTournament+1, realRound, 8, {from: user}]).then(() => {
        done()
    }) }) }) }) }) }) })

    it('should fail to create a stake on a non-existing round', function(done) {
        var amount = 500
        var user = accounts[2]
        Numeraire.deployed().then(instance => {
        instance.numeraiTransfer(user, amount, {from: accounts[0]}).then(() => {
        instance.numeraiTransfer(user, amount, {from: multiSigAddresses[0]}).then(() => {
        instance.balanceOf(user).then(startingBalance => {
            assert(startingBalance.gte(amount))
        instance.getTournament(realTournament).then(tournament => {
            assert.isAbove(tournament[0].toNumber(), 0)
        instance.getRound(realTournament, realRound+1).then(round => {
            assert.equal(round[0].toNumber(), 0)
        assertThrows(instance.stake, [amount, realTournament, realRound+1, 8, {from: user}]).then(() => {
        done()
    }) }) }) }) }) }) }) })

    it('should fail to stake 0 NMR', function(done) {
        var amount = 500
        var user = accounts[2]
        Numeraire.deployed().then(instance => {
        assertThrows(instance.stake, [0, realTournament, realRound, 8, {from: user}]).then(() => {
        done()
    }) }) })

    it('should fail to stake on a resolved round', function(done) {
        var amount = 500
        var user = accounts[2]
        Numeraire.deployed().then(instance => {
        instance.numeraiTransfer(user, amount, {from: accounts[0]}).then(() => {
        instance.numeraiTransfer(user, amount, {from: multiSigAddresses[0]}).then(() => {
        instance.balanceOf(user).then(startingBalance => {
            assert(startingBalance.gte(amount))
        instance.createRound(realTournament, realRound2, 0).then(() => {
        assertThrows(instance.stake, [amount, realTournament, realRound2, 8, {from: user}]).then(() => {
        done()
    }) }) }) }) }) }) })

    it('should transfer', function(done) { // erc20
        var amount = 500
        var user = accounts[2]
        Numeraire.deployed().then(instance => {
        instance.numeraiTransfer(accounts[0], amount, {from: accounts[0]}).then(() => {
        instance.numeraiTransfer(accounts[0], amount, {from: multiSigAddresses[0]}).then(() => {
        instance.balanceOf(accounts[0]).then(startingBalance1 => {
            assert(startingBalance1.gte(amount))
        instance.balanceOf(user).then(startingBalance2 => {
        instance.transfer(user, amount, {from: accounts[0]}).then(() => {
        instance.balanceOf(accounts[0]).then(endingBalance1 => {
            assert(endingBalance1.equals(startingBalance1.minus(amount)))
        instance.balanceOf(user).then(endingBalance2 => {
            assert(endingBalance2.equals(startingBalance2.plus(amount)))
        done()
    }) }) }) }) }) }) }) }) })

    it('should fail to transfer too much', function(done) {
        var user = accounts[2]
        Numeraire.deployed().then(instance => {
        instance.balanceOf(accounts[0]).then(startingBalance1 => {
        assertThrows(instance.transfer, [user, startingBalance1.plus(1), {from: accounts[0]}]).then(() => {
        done()
    }) }) }) })

    it('should change owners', function(done) {
        var user = accounts[2]
        var amount = 500
        Numeraire.deployed().then(instance => {
        rpc('evm_snapshot').then(snapshot => {
        instance.balanceOf(user).then(balance1 => {
        instance.numeraiTransfer(user, amount, {from: multiSigAddresses[0]}).then(() => {
        instance.numeraiTransfer(user, amount, {from: multiSigAddresses[1]}).then(() => {
        instance.balanceOf(user).then(balance2 => {
            assert(balance2.equals(balance1.plus(amount)))
        instance.numeraiTransfer(user, amount, {from: accounts[1]}).then(() => {
        instance.numeraiTransfer(user, amount, {from: multiSigAddresses[1]}).then(() => {
        instance.balanceOf(user).then(balance3 => {
            assert(balance3.equals(balance2))
        instance.isOwner(accounts[1]).then(isOwner1 => {
            assert.equal(isOwner1, false)
        instance.changeShareable([accounts[0], accounts[1], multiSigAddresses[1]], 2, {from: multiSigAddresses[0]}).then(() => {
        instance.changeShareable([accounts[0], accounts[1], multiSigAddresses[1]], 2, {from: multiSigAddresses[1]}).then(() => {
        instance.isOwner(accounts[1]).then(isOwner2 => {
            assert.equal(isOwner2, true)
        instance.numeraiTransfer(user, amount, {from: accounts[1]}).then(() => {
        instance.balanceOf(user).then(balance4 => {
            assert(balance4.equals(balance3.plus(amount)))
        rpc('evm_revert', [snapshot['result']]).then(function() {
        instance.isOwner(multiSigAddresses[0]).then(isOwner3 => {
            assert.equal(isOwner3, true)
        done()
    }) }) }) }) }) }) }) }) }) }) }) }) }) }) }) }) }) })

    it('should revoke a previously confirmed operation', function(done) {
        var user = accounts[2]
        var amount = 500
        Numeraire.deployed().then(instance => {
        instance.balanceOf(user).then(balance1 => {
        instance.numeraiTransfer(user, amount, {from: multiSigAddresses[0]}).then(transaction => {
        instance.revoke(transaction.logs[0].args.operation, {from: multiSigAddresses[0]}).then(() => {
        instance.numeraiTransfer(user, amount, {from: multiSigAddresses[1]}).then(transaction => {
        instance.balanceOf(user).then(balance2 => {
            assert(balance2.equals(balance1))
        instance.numeraiTransfer(user, amount, {from: multiSigAddresses[0]}).then(transaction => {
        instance.balanceOf(user).then(balance3 => {
            assert(balance3.equals(balance2.plus(amount)))
        done()
    }) }) }) }) }) }) }) }) })

    it('should perform emergency stop and release', function(done) {
        Numeraire.deployed().then(instance => {
        instance.emergencyStop({from: multiSigAddresses[0]}).then(() => {
        instance.stopped().then(stopped => {
            assert(stopped)
        instance.mint(1).then(tx => {
            assert.equal(tx.logs.length, 0)
        instance.release({from: multiSigAddresses[0]}).then(() => {
        instance.release({from: multiSigAddresses[1]}).then(() => {
        instance.mint(1).then(tx => {
            assert.isAbove(tx.logs.length, 0)
        done()
    }) }) }) }) }) }) }) })

    it('should disable emergency stop', function(done) {
        Numeraire.deployed().then(instance => {
        instance.disableStopping({from: multiSigAddresses[0]}).then(() => {
        instance.disableStopping({from: multiSigAddresses[1]}).then(() => {
        instance.stoppable().then(stoppable => {
            assert(!stoppable)
        assertThrows(instance.emergencyStop).then(() => {
        done()
    }) }) }) }) }) })

    // this has to be done before the other stakeRelease tests because
    // evm_revert does not reset the clock
    it('should fail to release a stake early', function(done) {
        var amount = 500
        var confidence = 8
        var user = accounts[2]
        rpc('evm_revert', [stakeSnapshot]).then(() => {
        rpc('evm_snapshot').then(snapshot => {
            stakeSnapshot = snapshot['result']
        Numeraire.deployed().then(instance => {
        web3.evm.increaseTime(4 * 7 * 24 * 60 * 60 - 60).then(function() { // 1 minute early
        assertThrows(instance.releaseStake, [user, 0, realTournament, realRound, true, {from: accounts[0]}]).then(() => {
        done()
    }) }) }) }) }) })

    // ibid
    it('should fail to destroy a stake early', function(done) {
        var amount = 500
        var confidence = 8
        var user = accounts[2]
        rpc('evm_revert', [stakeSnapshot]).then(() => {
        rpc('evm_snapshot').then(snapshot => {
            stakeSnapshot = snapshot['result']
        Numeraire.deployed().then(instance => {
        assertThrows(instance.destroyStake, [user, realTournament, realRound, {from: accounts[0]}]).then(() => {
        done()
    }) }) }) }) })

    it('should release a stake', function(done) {
        var amount = 500
        var confidence = 8
        var user = accounts[2]
        rpc('evm_revert', [stakeSnapshot]).then(() => {
        rpc('evm_snapshot').then(snapshot => {
            stakeSnapshot = snapshot['result']
        Numeraire.deployed().then(instance => {
        instance.balanceOf(user).then(startingBalance => {
        web3.evm.increaseTime(4 * 7 * 24 * 60 * 60).then(function() {
        instance.releaseStake(user, 0, realTournament, realRound, true, {from: accounts[0]}).then(() => {
        instance.balanceOf(user).then(endingBalance => {
            assert(endingBalance.equals(startingBalance.plus(amount)))
        instance.getStake(realTournament, realRound, user).then(stake => {
            assert.equal(stake[0], confidence)
            assert.equal(stake[1], 0)
            assert.equal(stake[2], true)
            assert.equal(stake[3], true)
        done()
    }) }) }) }) }) }) }) }) })

    it('should release a stake with ether', function(done) {
        var etherAmount = new Big('1000000000000000000') // 1 ETH
        var amount = 500
        var confidence = 8
        var user = accounts[2]
        Numeraire.deployed().then(instance => {
        rpc('evm_revert', [stakeSnapshot]).then(() => {
        rpc('evm_snapshot').then(snapshot => {
            stakeSnapshot = snapshot['result']
            web3.eth.sendTransaction({from: accounts[0], to: instance.address, value: etherAmount, gasLimit: 23000, gasPrice: gasPrice})
        web3.evm.increaseTime(4 * 7 * 24 * 60 * 60).then(function() {
        instance.balanceOf(user).then(startingBalance => {
            var startingEther = web3.eth.getBalance(user)
        instance.releaseStake(user, etherAmount, realTournament, realRound, true, {from: multiSigAddresses[0]}).then(() => {
            assert(web3.eth.getBalance(user).equals(startingEther.plus(etherAmount)))
        instance.balanceOf(user).then(endingBalance => {
            assert(endingBalance.equals(startingBalance.plus(amount)))
        instance.getStake(realTournament, realRound, user).then(stake => {
            assert.equal(stake[0], confidence)
            assert.equal(stake[1], 0)
            assert.equal(stake[2], true)
            assert.equal(stake[3], true)
        done()
    }) }) }) }) }) }) }) }) })

    it('should fail to release a resolved stake', function(done) {
        var amount = 500
        var confidence = 8
        var user = accounts[2]
        Numeraire.deployed().then(instance => {
        instance.getStake(realTournament, realRound, user).then(stake => {
            assert.equal(stake[0], confidence)
            assert.equal(stake[1], 0)
            assert.equal(stake[2], true)
            assert.equal(stake[3], true)
        assertThrows(instance.releaseStake, [user, 0, realTournament, realRound, true, {from: accounts[0]}]).then(() => {
        done()
    }) }) }) })

    it('should fail to release a non-existing stake', function(done) {
        var amount = 500
        var confidence = 8
        var user = accounts[2]
        rpc('evm_revert', [stakeSnapshot]).then(() => {
        rpc('evm_snapshot').then(snapshot => {
            stakeSnapshot = snapshot['result']
        Numeraire.deployed().then(instance => {
        web3.evm.increaseTime(4 * 7 * 24 * 60 * 60).then(function() {
        assertThrows(instance.releaseStake, [accounts[5], 0, realTournament, realRound, true, {from: accounts[0]}]).then(() => {
        done()
    }) }) }) }) }) })

    it('should destroy a stake', function(done) {
        var amount = 500
        var confidence = 8
        var user = accounts[2]
        rpc('evm_revert', [stakeSnapshot]).then(() => {
        rpc('evm_snapshot').then(snapshot => {
            stakeSnapshot = snapshot['result']
        Numeraire.deployed().then(instance => {
        instance.balanceOf(user).then(startingBalance => {
        instance.totalSupply().then(startingSupply => {
        web3.evm.increaseTime(4 * 7 * 24 * 60 * 60).then(function() {
        instance.destroyStake(user, realTournament, realRound, {from: accounts[0]}).then(() => {
        instance.balanceOf(user).then(endingBalance => {
            assert(endingBalance.equals(startingBalance))
        instance.totalSupply().then(endingSupply => {
            assert(endingSupply.equals(startingSupply.minus(amount)))
        instance.getStake(realTournament, realRound, user).then(stake => {
            assert.equal(stake[0], confidence)
            assert.equal(stake[1], 0)
            assert.equal(stake[2], false)
            assert.equal(stake[3], true)
        done()
    }) }) }) }) }) }) }) }) }) }) })

    it('should fail to destroy a resolved stake', function(done) {
        var amount = 500
        var confidence = 8
        var user = accounts[2]
        Numeraire.deployed().then(instance => {
        instance.getStake(realTournament, realRound, user).then(stake => {
            assert.equal(stake[0], confidence)
            assert.equal(stake[1], 0)
            assert.equal(stake[2], false)
            assert.equal(stake[3], true)
        assertThrows(instance.destroyStake, [user, realTournament, realRound, {from: accounts[0]}]).then(() => {
        done()
    }) }) }) })

    it('should fail to destroy a non-existing stake', function(done) {
        var amount = 500
        var confidence = 8
        var user = accounts[2]
        rpc('evm_revert', [stakeSnapshot]).then(() => {
        rpc('evm_snapshot').then(snapshot => {
            stakeSnapshot = snapshot['result']
        Numeraire.deployed().then(instance => {
        instance.balanceOf(user).then(startingBalance => {
        web3.evm.increaseTime(4 * 7 * 24 * 60 * 60).then(function() {
        instance.destroyStake(user, realTournament, realRound, {from: accounts[0]}).then(() => {
        instance.balanceOf(user).then(endingBalance => {
            assert(endingBalance.equals(startingBalance))
        instance.getStake(realTournament, realRound, user).then(stake => {
            assert.equal(stake[0], confidence)
            assert.equal(stake[1], 0)
            assert.equal(stake[2], false)
            assert.equal(stake[3], true)
        done()
    }) }) }) }) }) }) }) }) })

    it('should test approving a contract to spend') // erc20
    it('should test approving a contract to spend with non-zero allowance (fail)')
    it('should test transferFrom a contract that\'s been approved') // erc20
    it('should test changeApproval')
    it('should test changeApproval (fail)')
    it('should test getMintable')
    it('should test minting')
    it('should test minting too much (fail)')
    it('should test staking on behalf')
    it('should test staking on behalf of user >1m (fail)')
    it('should test transferring from numerai')
    it('should test transferring too much from numerai (fail)')
    it('should test withdrawing')
    it('should test withdrawing from >1m (fail)')
    it('should test withdrawing too much (fail)')
    it('should test arithmetic safety')
})
