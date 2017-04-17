pragma solidity ^0.4.10;

// A simple contract created for each Numerai user who wants to deposit NMR to Numerai so that it can be staked in the competition

import "contracts/Destructible.sol";

contract Deposit is Destructible {

    address public numeraire;

    // At creation time it must know the address of the Numeraire contract
    function Deposit(address _numeraire) {
        numeraire = _numeraire;
    }

    // Allow Numerai to withdraw deposited NMR
    function approve(uint256 _value) onlyOwner returns (bool success) {
        return numeraire.call(bytes4(sha3("approve(address, uint256)")), msg.sender, _value);
    }
}
