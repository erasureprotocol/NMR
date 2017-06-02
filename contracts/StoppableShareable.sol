pragma solidity ^0.4.11;

import "contracts/Shareable.sol";

// From OpenZepplin: https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/lifecycle/Pausable.sol
/*
 * Stoppable
 * Abstract contract that allows children to implement an
 * emergency stop mechanism.
 */
contract StoppableShareable is Shareable {
  bool public stopped;
  bool public stoppable = true;

  modifier stopInEmergency { if (!stopped) _; }
  modifier onlyInEmergency { if (stopped) _; }

  function StoppableShareable(address[] _owners, uint _required) Shareable(_owners, _required) {
  }

  // called by the owner on emergency, triggers stopped state
  function emergencyStop() external onlyOwner {
    assert(stoppable);
    stopped = true;
  }

  // called by the owners on end of emergency, returns to normal state
  function release() external onlyManyOwners(sha3(msg.data)) {
    assert(stoppable);
    stopped = false;
  }

  // called by the owners to disable ability to begin or end an emergency stop
  function disableStopping() external onlyManyOwners(sha3(msg.data)) {
    stoppable = false;
  }
}
