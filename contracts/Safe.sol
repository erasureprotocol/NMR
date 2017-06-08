pragma solidity ^0.4.11;


contract Safe {
    // Check if it is safe to add two numbers
    function safeAdd(uint a, uint b) internal returns (uint) {
        uint c = a + b;
        assert(c >= a && c >= b);
        return c;
    }

    // Check if it is safe to subtract two numbers
    function safeSubtract(uint a, uint b) internal returns (uint) {
        uint c = a - b;
        assert(b <= a && c <= a);
        return c;
    }

    function safeMultiply(uint a, uint b) internal returns (uint) {
        uint c = a * b;
        assert(a == 0 || (c / a) == b);
        return c;
    }

    function shrink128(uint a) internal returns (uint128) {
        assert(a < 0x100000000000000000000000000000000);
        return uint128(a);
    }

    // mitigate short address attack
    modifier onlyPayloadSize(uint numWords) {
        assert(msg.data.length == numWords * 32 + 4);
        _;
    }

    // allow ether to be received
    function () payable { }
}
