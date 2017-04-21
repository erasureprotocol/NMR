pragma solidity ^0.4.8;

import "ds-auth/auth.sol";

// From OpenZepplin: https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/lifecycle/Destructible.sol
/*
 * Destructible
 * Base contract that can be destroyed by owner. All funds in contract will be sent to the owner.
 */
contract Destructible is DSAuth {

  function destroy() auth {
    selfdestruct(msg.sender);
  }
}
