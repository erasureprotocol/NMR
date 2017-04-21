pragma solidity ^0.4.8;

import "ds-auth/auth.sol";


// From OpenZepplin: https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/lifecycle/Pausable.sol
/*
 * Stoppable
 * Abstract contract that allows children to implement an
 * emergency stop mechanism.
 */
contract Stoppable is DSAuth {
  bool public stopped;

  modifier stopInEmergency { if (!stopped) _; }
  modifier onlyInEmergency { if (stopped) _; }

  // called by the owner on emergency, triggers stopped state
  function emergencyStop() external auth {
    stopped = true;
  }

  // called by the owner on end of emergency, returns to normal state
  function release() external auth onlyInEmergency {
    stopped = false;
  }
}
