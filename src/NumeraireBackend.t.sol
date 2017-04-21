pragma solidity ^0.4.10;

import "ds-test/test.sol";
import "./NumeraireBackend.sol";
import "./NumeraireDelegate.sol";

contract TestNumeraireBackend is DSTest {

    NumeraireBackend backend;
    NumeraireDelegate delegate;
    address delegateAddress;
    uint256 initialDisbursement = 1500000000000000000000000; // 1.5 million
    uint256 public supply_max = 21000000000000000000000000; // 21 million

    // token will be instantiated before each test case
    function setUp() {
        backend = new NumeraireBackend(initialDisbursement);
        delegate = new NumeraireDelegate();
        delegateAddress = delegate;
        backend.changeDelegate(delegate);
    }

    function testInitialSupply() {
        assertEq(backend.totalSupply(), 0);
        assertEq(backend.supply_max(), supply_max);
    }

    function testDelegateAddress() {
        assert(backend.delegateContract() == delegateAddress);
    }

    function testInitialDisbursement() {
        assert(initialDisbursement == backend.disbursement());
    }

    function testMintInitialDisbursement() {
        assertEq(backend.totalSupply(), 0);
        assertEq(backend.supply_max(), 21000000000000000000000000);
        backend.mint(1);
    }

    function testFailMintNoMoreThanDisbursement() {
        backend.mint(initialDisbursement + 1);
    }

}
