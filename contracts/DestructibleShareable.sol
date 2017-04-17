pragma solidity ^0.4.10;


import "contracts/Shareable.sol";

// From OpenZepplin: https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/lifecycle/Destructible.sol
/*
 * Destructible
 * Base contract that can be destroyed by owner. All funds in contract will be sent to the owner.
 */
contract DestructibleShareable is Shareable {
  function DestructibleShareable(address[] _owners, uint _required) Shareable(_owners, _required) {
  }

  function destroy() onlyManyOwners(sha3(msg.data)) {
    selfdestruct(msg.sender);
  }
}
