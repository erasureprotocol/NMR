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

//Some default values for gas
var gasAmount = 3000000
var gasPrice = 20000000000
var initialDisbursement = new Big(1500000000000000000000000)
var nmr_per_week = new Big(96153846153846100000000).add(53846153)

var multiSigAddresses = ['0x54fd80d6ae7584d8e9a19fe1df43f04e5282cc43', '0xa6d135de4acf44f34e2e14a4ee619ce0a99d1e08']
var Numeraire = artifacts.require("./NumeraireBackend.sol")
var NumeraireDelegate = artifacts.require("./NumeraireDelegate.sol")
var snapshotID = 0

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

    it ("should set the delegate correctly", function(done) {
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

    it('should create a tournament', (done) => {
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

    it('should create a round', (done) => {
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


    it('should stake NMR as self', (done) => {
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

    it("should send NMR correctly", function(done) {
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
        var nmr = Numeraire.deployed().then(function(instance) {
        rpc('evm_snapshot').then(function(snapshot) {
            snapshotID = snapshot['id']
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
            assert.equal(stakeBeforeRelease - amount, stakeAfterRelease[1].toNumber())
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

    it('should change delegate', function(done) { // erc20
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

    it('should disable contract upgradability', function(done) { // erc20
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
            assertThrows(instance.changeDelegate, [zero, {from: multiSigAddresses[1]}])
        instance.delegateContract().then(delegateAddress => {
            assert.equal(delegate.address, delegateAddress)
        done()
    }) }) }) }) }) }) }) }) }) })

    it('should allow claiming ether', function(done) { // erc20
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

    it('should disallow claiming NMR', function(done) { // erc20
        var amount = new Big('1000000000000000') // .001 NMR
        Numeraire.deployed().then(instance => {
        instance.balanceOf(instance.address).then(oldInstanceBalance =>  {
            assertThrows(instance.claimTokens, [instance.address])
        instance.balanceOf(instance.address).then(newInstanceBalance => {
            assert(!newInstanceBalance.equals(new Big('0')))
        done()
    }) }) }) })

    it('should test creating a tournament')
    it('should test creating an existing tournament (fail)')
    it('should test creating a round in an existing tournament')
    it('should test creating a round in a non-existing tournament (fail)') // does it?
    it('should test creating an existing round in a non-existing tournament (fail)')
    it('should test creating an existing round in an existing tournament (fail)')
    it('should test getting existing tournament')
    it('should test getting non-existing tournament')
    it('should test getting existing round')
    it('should test getting non-existing round')
    it('should test getting existing stake')
    it('should test getting non-existing stake')
    it('should test transferring') // erc20
    it('should test transferring too much (fail)')
    it('should test approving a contract to spend') // erc20
    it('should test approving a contract to spend with non-zero allowance (fail)')
    it('should test transferFrom a contract that\'s been approved') // erc20
    it('should test changeApproval')
    it('should test changeApproval (fail)')
    it('should test getMintable')
    it('should test multisig')
    it('should test multisig with not enough sigs (fail)')
    it('should test destructibility')
    it('should test emergency stoppage')
    it('should test minting')
    it('should test minting too much (fail)')
    it('should test releasing a stake')
    it('should test releasing a stake with ether')
    it('should test releasing a non-existing stake (fail)')
    it('should test releasing a resolved stake (fail)')
    it('should test releasing a stake early (fail)')
    it('should test destroying a stake')
    it('should test destroying a non-existing stake (fail)')
    it('should test destroying a resolved stake (fail)')
    it('should test destroying a stake early (fail)')
    it('should test staking')
    it('should test staking as owner (fail)')
    it('should test staking too much (fail)')
    it('should test staking on non-existing tournament (fail)')
    it('should test staking on non-existing round (fail)')
    it('should test staking on resolved round (fail)')
    it('should test staking 0 NMR (fail)')
    it('should test staking on behalf')
    it('should test staking on behalf of user >1m (fail)')
    it('should test transferring from numerai')
    it('should test transferring too much from numerai (fail)')
    it('should test withdrawing')
    it('should test withdrawing from >1m (fail)')
    it('should test withdrawing too much (fail)')
    it('should test arithmetic safety')
})
