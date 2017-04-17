pragma solidity ^0.4.10;


contract Safe {
    // Check if it is safe to add two numbers
    function safeToAdd(uint a, uint b) internal returns (bool) {
        uint c = a + b;
        return (c >= a && c >= b);
    }

    // Check if it is safe to subtract two numbers
    function safeToSubtract(uint a, uint b) internal returns (bool) {
        return (b <= a && a - b <= a);
    }

    function safeToMultiply(uint a, uint b) internal returns (bool) {
        uint c = a * b;
        return(a == 0 || (c / a) == b);
    }

    // prevents accidental sending of ether
    function () {
        throw;
    }
}
