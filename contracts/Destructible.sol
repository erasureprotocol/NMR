pragma solidity ^0.4.10;


import "contracts/Ownable.sol";


// From OpenZepplin: https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/lifecycle/Destructible.sol
/*
 * Destructible
 * Base contract that can be destroyed by owner. All funds in contract will be sent to the owner.
 */
contract Destructible is Ownable {
  function destroy() onlyOwner {
    selfdestruct(owner);
  }
}
