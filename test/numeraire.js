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

    it("should not mint more than disbursement", function(done) {
        var prevBalance;
        var nmr = Numeraire.deployed().then(function(instance) {
            prevBalance = web3.eth.getBalance(accounts[0]);
            return instance.mint(accounts[1], 750000000000000000000001, {
                    from: accounts[0],
                    gasPrice: gasPrice,
                    gas: gasAmount
                })
                .catch(ifUsingTestRPC)
                .then(function() {
                    checkAllGasSpent(gasAmount, gasPrice, accounts[0], prevBalance);
                })
                .then(done)
                .catch(done);
        });
    });

    it('should reduce disbursement [by double, 1 for numerai, 1 for users] when minting', function(done) {
        var nmr = Numeraire.deployed().then(function(instance) {
            return instance.disbursement.call().then(function(last_disbursement) {
                return instance.mint(accounts[2], 10000000000, {
                    from: accounts[0]
                }).then(function() {
                    instance.disbursement.call().then(function(disbursement) {
                        assert.equal(disbursement.toNumber(), last_disbursement.toNumber() - 20000000000);
                        done();
                    });
                });
            });
        });
    });

    it("should reset disbursement once per week", function(done) {
        var nmr = Numeraire.deployed().then(function(instance) {
            return instance.disbursement.call().then(disbursement => {
                return instance.mint(accounts[1], 500000, {
                    from: accounts[0]
                }).then(() => {
                    return web3.evm.increaseTime(7 * 25 * 60 * 60).then(() => {
                        return instance.mint(accounts[1], 20000000000, {
                            from: accounts[0]
                        }).then(() => {
                            return instance.disbursement.call().then(disbursement => {
                                assert.equal(9.615384615384615e+22 - 40000000000, disbursement.toNumber());
                                done();
                            });
                        });
                    });
                });
            });
        });
    });

    it("should send NMR correctly", function(done) {
        var nmr = Numeraire.deployed().then(function(instance) {
            // Get initial balances of first and second account.
            var account_one = accounts[1];
            var account_two = accounts[2];

            var account_one_starting_balance;
            var account_two_starting_balance;
            var account_one_ending_balance;
            var account_two_ending_balance;

            var amount = 1000000000;

            return instance.mint(accounts[1], amount, {
                from: accounts[0]
            }).then(function() {
                return instance.balanceOf.call(account_one).then(function(balance) {
                    account_one_starting_balance = balance.toNumber();
                    return instance.balanceOf.call(account_two);
                }).then(function(balance) {
                    account_two_starting_balance = balance.toNumber();
                    return instance.transfer(account_two, amount, {
                        from: account_one
                    });
                }).then(function() {
                    return instance.balanceOf.call(account_one);
                }).then(function(balance) {
                    account_one_ending_balance = balance.toNumber();
                    return instance.balanceOf.call(account_two);
                }).then(function(balance) {
                    account_two_ending_balance = balance.toNumber();

                    assert.equal(account_one_ending_balance, account_one_starting_balance - amount, "Amount wasn't correctly taken from the sender");
                    assert.equal(account_two_ending_balance, account_two_starting_balance + amount, "Amount wasn't correctly sent to the receiver");
                    done();
                });
            });
        });
    });

    // read
    it('should stake NMR', (done) => {
        var nmr = Numeraire.deployed().then(function(instance) {
            return instance.balanceOf.call(accounts[0])
                .then(() => instance.balanceOf.call(accounts[1]).then((balance) => {
                    return instance.stake(accounts[1], 500, {
                        from: accounts[0]
                    }).then(() => {
                        // check if stakers balance has been reduced
                        return instance.balanceOf.call(accounts[1]).then((balance_after) => {
                            assert.equal(balance.toNumber() - 500, balance_after.toNumber());
                            done();
                        });
                    });
                }));
        });
    });

    it('should release stake', function(done) {
        var nmr = Numeraire.deployed().then(function(instance) {
            return instance.stake(accounts[1], 500, {from: accounts[0]}).then(function(tx_id) {
                var block = web3.eth.getBlock(tx_id.receipt.blockNumber);
                return instance.releaseStake.call(accounts[1], block.timestamp, {from: accounts[0]}).then(function(result) {
                    assert.equal(result, true);
                    done();
                });
            });
        });
    });

    it('should destroy stake', function(done) {
        var nmr = Numeraire.deployed().then(function(instance) {
            return instance.stake(accounts[1], 500, {from: accounts[0]}).then(function(tx_id) {
                var block = web3.eth.getBlock(tx_id.receipt.blockNumber);
                return instance.destroyStake.call(accounts[1], block.timestamp, {from: accounts[0]}).then(function(result) {
                    assert.equal(result, true);
                    done();
                });
            });
        });
    });
});