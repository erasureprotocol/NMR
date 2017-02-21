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
        var nmr = Numeraire.deployed().then(function(instance) {
            return instance.mint(accounts[1], 759999999999990000000000, {
                    from: accounts[0]
                }).then(() => {
                    throw 'minted more than disbursement';
                })
                .catch(error => {
                    if (error === 'minted more than disbursement') {
                        throw error;
                    }
                });
            done();
        });
    });

    it('should reduce disbursement when minting', (done) => {
        var nmr = Numeraire.deployed().then(function(instance) {

            return instance.disbursement.call(accounts[0]).then(last_disbursement => {
                return instance.mint(accounts[2], 1, {
                        from: accounts[0]
                    })
                    .then(() => instance.disbursement.call(accounts[0]))
                    .then(disbursement => {
                        assert.equal(disbursement.toNumber() + 2, last_disbursement.toNumber())
                    })
            })
            done();

        });

    });

    it("should reset disbursement once per week", function(done) {
        var nmr = Numeraire.deployed().then(function(instance) {
            return instance.disbursement.call(accounts[0]).then(disbursement => {
                return instance.mint(accounts[1], disbursement.toNumber() / 2, {
                    from: accounts[0]
                }).then(() => {
                    return web3.evm.increaseTime(7 * 25 * 60 * 60).then(() => {
                        return instance.mint(accounts[1], 2400000000000, {
                            from: accounts[0]
                        }).then(() => {
                            return instance.disbursement.call(accounts[0]).then(disbursement => {
                                assert.equal(disbursement.toNumber(), 200000000000);
                            });
                        });
                    });
                });
            });
            done();
        });
    });

    it("should not mint more than 10,000,000", function(done) {
        var nmr = Numeraire.deployed().then(function(instance) {
            return instance.mint(accounts[1], 510000000000000, {
                    from: accounts[0]
                }).then(() => {
                    throw 'minted more than 10,000,000';
                })
                .catch(error => {
                    if (error === 'minted more than 10,000,000') {
                        throw error;
                    }
                });
            done();
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
                });
            });
            done();
        });

    });

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
                        })
                    })
                    done();
                }))
        })
    });

    it('should release stake', function(done) {
        var nmr = Numeraire.deployed().then(function(instance) {
            return instance.stake(accounts[1], 500, {
                from: accounts[0]
            }).then(tx_id => {
                var txn = web3.eth.getTransaction(tx_id);
                var block = web3.eth.getBlock(txn.blockNumber);
                return instance.releaseStake(accounts[1], block.timestamp, {
                    from: accounts[0]
                });
            });
        });
        done();
    });

    it('should destroy stake', function(done) {
        var nmr = Numeraire.deployed().then(function(instance) {
            return instance.stake(accounts[1], 500, {
                from: accounts[0]
            }).then(tx_id => {
                var txn = web3.eth.getTransaction(tx_id);
                var block = web3.eth.getBlock(txn.blockNumber);
                return instance.destroyStake(accounts[1], 1, {
                    from: accounts[0]
                });
            });
        });
        done();
    });
});