function rpc(method, arg) {
    var req = {
        jsonrpc: "2.0",
        method: method,
        id: new Date().getTime()
    };
    if (arg) req.params = arg;

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
    var newBalance = web3.eth.getBalance(account);
    assert.equal(prevBalance.minus(newBalance).toNumber(), gasAmount * gasPrice, 'Incorrect amount of gas used');
}

function ifUsingTestRPC() {
    return;
}

//Some default values for gas
var gasAmount = 3000000;
var gasPrice = 20000000000;

var Numeraire = artifacts.require("./Numeraire.sol");

contract('Numeraire', function(accounts) {
    before(function() {
        var nmr = Numeraire.deployed().then(function(instance) {
            return instance.mint(accounts[1], 10000000000, {
                from: accounts[0]
            });
        });
    });

    it("should mint NMR correctly", function(done) {
        var nmr = Numeraire.deployed().then(function(instance) {
            return instance.balanceOf.call(accounts[1]).then(function(balance) {
                // check if recipient has minted amount
                assert.equal(balance.toNumber(), 10000000000);
                return instance.balanceOf.call(instance.address).then(function(balance) {
                    // check if Numerai has minted amount
                    assert.equal(balance.toNumber(), 10000000000);

                    return instance.totalSupply.call().then(function(supply) {
                        // check if supply has increased by minted amounts
                        assert.equal(supply.toNumber(), 20000000000);
                        done();
                    });
                });
            });
        });
    });
});