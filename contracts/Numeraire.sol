pragma solidity ^0.4.8;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Dependencies
/*
 * Ownable
 *
 * Base contract with an owner.
 * Provides onlyOwner modifier, which prevents function from running if it is called by anyone other than the owner.
 */
contract Ownable {
  address public owner;

  function Ownable() {
    owner = msg.sender;
  }

  modifier onlyOwner() {
    if (msg.sender == owner)
      _;
  }

  function transferOwnership(address newOwner) onlyOwner {
    if (newOwner != address(0)) owner = newOwner;
  }

}
/*
 * Stoppable
 * Abstract contract that allows children to implement an
 * emergency stop mechanism.
 */
contract Stoppable is Ownable {
  bool public stopped;

  modifier stopInEmergency { if (!stopped) _; }
  modifier onlyInEmergency { if (stopped) _; }

  // called by the owner on emergency, triggers stopped state
  function emergencyStop() external onlyOwner {
    stopped = true;
  }

  // called by the owner on end of emergency, returns to normal state
  function release() external onlyOwner onlyInEmergency {
    stopped = false;
  }

}

/*
 * Sharable
 * 
 * Effectively our multisig contract
 *
 * Based on https://github.com/ethereum/dapp-bin/blob/master/wallet/wallet.sol
 *
 * inheritable "property" contract that enables methods to be protected by requiring the acquiescence of either a single, or, crucially, each of a number of, designated owners.
 *
 * usage:
 * use modifiers onlyowner (just own owned) or onlymanyowners(hash), whereby the same hash must be provided by some number (specified in constructor) of the set of owners (specified in the constructor) before the interior is executed.
 */
contract Sharable {
  // TYPES

  // struct for the status of a pending operation.
  struct PendingState {
    uint yetNeeded;
    uint ownersDone;
    uint index;
  }


  // FIELDS

  // the number of owners that must confirm the same operation before it is run.
  uint public required;

  // list of owners
  uint[256] owners;
  uint constant c_maxOwners = 250;
  // index on the list of owners to allow reverse lookup
  mapping(uint => uint) ownerIndex;
  // the ongoing operations.
  mapping(bytes32 => PendingState) pendings;
  bytes32[] pendingsIndex;


  // EVENTS

  // this contract only has six types of events: it can accept a confirmation, in which case
  // we record owner and operation (hash) alongside it.
  event Confirmation(address owner, bytes32 operation);
  event Revoke(address owner, bytes32 operation);


  // MODIFIERS

  // simple single-sig function modifier.
  modifier onlyOwner {
    if (isOwner(msg.sender))
      _;
  }

  // multi-sig function modifier: the operation must have an intrinsic hash in order
  // that later attempts can be realised as the same underlying operation and
  // thus count as confirmations.
  modifier onlymanyowners(bytes32 _operation) {
    if (confirmAndCheck(_operation))
      _;
  }


  // CONSTRUCTOR

  // constructor is given number of sigs required to do protected "onlymanyowners" transactions
  // as well as the selection of addresses capable of confirming them.
  function Sharable(address[] _owners, uint _required) {
    owners[1] = uint(msg.sender);
    ownerIndex[uint(msg.sender)] = 1;
    for (uint i = 0; i < _owners.length; ++i) {
      owners[2 + i] = uint(_owners[i]);
      ownerIndex[uint(_owners[i])] = 2 + i;
    }
    required = _required;
  }


  // new multisig is given number of sigs required to do protected "onlymanyowners" transactions
  // as well as the selection of addresses capable of confirming them.
  // take all new owners as an array
  function changeSharable(address[] _owners, uint _required) onlymanyowners(sha3(msg.data)) {
    for (uint i = 0; i < _owners.length; ++i) {
      owners[1 + i] = uint(_owners[i]);
      ownerIndex[uint(_owners[i])] = 1 + i;
    }
    required = _required;
  }

  // METHODS

  // Revokes a prior confirmation of the given operation
  function revoke(bytes32 _operation) external {
    uint index = ownerIndex[uint(msg.sender)];
    // make sure they're an owner
    if (index == 0) return;
    uint ownerIndexBit = 2**index;
    var pending = pendings[_operation];
    if (pending.ownersDone & ownerIndexBit > 0) {
      pending.yetNeeded++;
      pending.ownersDone -= ownerIndexBit;
      Revoke(msg.sender, _operation);
    }
  }

  // Gets an owner by 0-indexed position (using numOwners as the count)
  function getOwner(uint ownerIndex) external constant returns (address) {
    return address(owners[ownerIndex + 1]);
  }

  function isOwner(address _addr) constant returns (bool) {
    return ownerIndex[uint(_addr)] > 0;
  }

  function hasConfirmed(bytes32 _operation, address _owner) constant returns (bool) {
    var pending = pendings[_operation];
    uint index = ownerIndex[uint(_owner)];

    // make sure they're an owner
    if (index == 0) return false;

    // determine the bit to set for this owner.
    uint ownerIndexBit = 2**index;
    return !(pending.ownersDone & ownerIndexBit == 0);
  }

  // INTERNAL METHODS

  function confirmAndCheck(bytes32 _operation) internal returns (bool) {
    // determine what index the present sender is:
    uint index = ownerIndex[uint(msg.sender)];
    // make sure they're an owner
    if (index == 0) return;

    var pending = pendings[_operation];
    // if we're not yet working on this operation, switch over and reset the confirmation status.
    if (pending.yetNeeded == 0) {
      // reset count of confirmations needed.
      pending.yetNeeded = required;
      // reset which owners have confirmed (none) - set our bitmap to 0.
      pending.ownersDone = 0;
      pending.index = pendingsIndex.length++;
      pendingsIndex[pending.index] = _operation;
    }
    // determine the bit to set for this owner.
    uint ownerIndexBit = 2**index;
    // make sure we (the message sender) haven't confirmed this operation previously.
    if (pending.ownersDone & ownerIndexBit == 0) {
      Confirmation(msg.sender, _operation);
      // ok - check if count is enough to go ahead.
      if (pending.yetNeeded <= 1) {
        // enough confirmations: reset and run interior.
        delete pendingsIndex[pendings[_operation].index];
        delete pendings[_operation];
        return true;
      }
      else
        {
          // not enough: record that this owner in particular confirmed.
          pending.yetNeeded--;
          pending.ownersDone |= ownerIndexBit;
        }
    }
  }

  function clearPending() internal {
    uint length = pendingsIndex.length;
    for (uint i = 0; i < length; ++i)
    if (pendingsIndex[i] != 0)
      delete pendings[pendingsIndex[i]];
    delete pendingsIndex;
  }

}

// End of dependencies
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/*

                                       ╓╓
                                    ▄▄▓▓▓▓▓▄
                                 ▄▄▓▓▓████▓▓▓▓▄
                              ▄▄▓▓█▓▓▄▄▓▓ ▐▓▓▓▓▓▓▄
                           ▄▄▓▓▓▓▓ ▓▓▓▓▓▓▌▐▓▓▓███▓▓▓▄
                        ▄▓▓▓▓▓▓▓▓▓ ▓▓▓▌└▓▓▓█▓▓▓▓▓▓▓▓▓▓▓▄
                     ▄▓▓▓▓▀▀▀▀▓▓▓▓▄▓▓▀▀▓▓▓▓  ▀▓▓▌▐▓▓▓▓▓▓▓▓▄
                 ╒▄▓▓▓▓▓▓▀▀▄▄▓▓▀▓▓▀▓▓▓▓▓▓▓▓ ▓▄╙▓▓▓▀└└└└└▓▓▓▓▓▄
               ▄▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▄╙▀▄▓▓▓▓ ╟▓▓ ╟▓▌▐▓▓▓▓▓▓▓▓▓▓▓▀▀▓▓▓▄
            ╓▓▓▓▓▓▀▀▀▀▀▀▀▐▓▓▓▀▓▓▓▓▓█▓▓▓ ╟▓▓▓▓▓▓▓▓▓▓▓▓╒▄╙▓▓▓ ▐▓▓▓▓▓▓▄
            ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ╟▓▓▓▓╓└└└┌▓▓▓▀▓▓▓▓▀▓▓▓ ╫▓ ╟▓▓▄▄▓▓▄╙▓▓▓
            ▓▓▀▀▀▀▀▀▀▓▓▓▀▀▄▄▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ╟▓▓▓▓▓▓▓▄▓▓▓▄▓▓▀▀▓▓▓▓▓▓▓
            ▓▓▓▓▓▀╓▄▓▓▓▓▓▄└▀▓▓▓▓▓▄▄▄▄▄▄▓▄▓▓▓▓▓▀▀▓▓▓▓█▓▓▓▓█████▓▓▓▓▓▓
            ▓▓▓▓▓▓▓▓▓▓▓▓▓▀▀▀▓▓▀▀▀▓▓▓▓▀▀▀▀▀▀▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
            ▓▓▓▓▓▓▓▓▀▐▓▓▌╒▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓ ▀▀▀▀▀▓▓▓▓▓▓▓▓▌▀▀▀▀▀▓▓
            ▓▓▓▓▄▓▓▓ ▐▓▓ ▓▓▌└▓▓▌ ╙▓▓▓▌▀▓▓▀╒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▌╒▓▓
            ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▌ ▄└▓▓▌╒▓▓▓▓▀▓▌▄▓▓▌▄▄▄▄▓└╟▓▓▓▓▓▓▓▌╒▓▓
            ▓▓▀╓╟▓▓▓▓▓▓▄▄▄▄▄▄▓▓▌ ▓▓ ▓▓▓▓▓▓▓█▓▓▓▓▀▀▀▀▀▓▓ ╟▓▓▓▓▀▓▓▓▄▓▓
            ▓▓ ╟▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▄▓▓▓▓▓▓▓█▀╓▄▓▓▓▓▄▓▓▓ ╟▓▓▓▓▀┌▄▓▓▓▓▓▓▓
            ▓▓▄▄▄▄▄▄▓▓▓ ▀▓╒▓▓▓▌┌▓▓▓▓▓▓▓▄▄▄▄▄▄▄▄▓▓▓▓▓▄▓▓▓▓▄▄▄▄▄▄▄▓▓▓▓
            ▀▓▓▓▓▓▓▓▓▓▓▓▄╓▓▓▓▓▓▀█▓▓▓▌ ▓▓▀█▓▓▓▓▀▀▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▀
              ▀▀▓▓▓▓▓▓▓▓▓▓▓█▀╒▄█▓▓▓▓▌ ▓▓▓ ▀▓▓ ╟▌└▓▓▓▀▓▓▓▀▓▄▓▓▓▓▓▓▀
                 ▀▀▓▓▓▄▄▄▓▓▄▄▄▄▄▄▄▓▓▓▓▓▓▓▓▓▓▌╒▓▓ ╟▓▓▓ ▀╒▓▓▓▓▓▓▀
                    ▀▀▓▓▓▓▌▀▓▓▓▓▓▓▓▌▄▄▄▄└▐▓▓▓▓▓▓▓▀▓▓▓▓▄▓▓▓▓▀
                       ▀▀▓▓▓▓└└└└└▓▓▓▓▓▓▌▐▓▓▓▓▀└▄▄▓▓▓▓▓█▀
                          ▀▀▓▓▓▓▓▓█▓▓▓▓▄▄▄▓▓▓▄▄▄▄▓▓▓▓▀
                             ▀▀▓▓▓▄└▓▓▓▓▓▓▀▀▓▓▓▓▓█▀
                                ▀▀▓▓▓▓▓▌▐▓▓▓▓▓█▀
                                   ▀▀▓▓▓▓▓▓█▀
                                      ▀▀▀▀
*/
// Whoever creates the contract has the power to stop it, this person can be changed via transferOwnership(_new_address)
contract Numeraire is Stoppable, Sharable {

    string public standard = "ERC20";
    string public name = "Numeraire";
    string public symbol = "NMR";
    uint256 public decimals = 18;

    address public numerai = this;

    // Cap the total supply at 21 million and the weekly supply at 50 thousand
    uint256 public supply_cap = 21000000000000000000000000;
    uint256 public disbursement_cap = 96153846153846153846153;

    uint256 public disbursement_period = 1 weeks;
    uint256 public disbursement_end_time;

    uint256 public disbursement;
    uint256 public total_supply;

    mapping (address => uint256) public balance_of;
    mapping (address => mapping (address => uint256)) public allowance_of;
    mapping (address => mapping (uint256 => uint256)) public staked;

    // Generates a public event on the blockchain to notify clients
    event Mint(address indexed recipient, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Stake(address indexed owner, uint256 indexed timestamp, uint256 value);

    // Initialization
    // Msg.sender is first owner
    function Numeraire(address[] _owners, uint256 _num_required, uint256 _initial_disbursement)
        Sharable(_owners, _num_required) {
        total_supply = 0;

        // The first disbursement period begins at contract initialization,
        // and may be larger than the weekly disbursement cap.
        if (!safeToAdd(block.timestamp, disbursement_period)) throw;
        disbursement_end_time = block.timestamp + disbursement_period;
        disbursement = _initial_disbursement;
    }

    // Mint
    // Can mint multiple times a week, just can't mint more than the cap in a week, then next week the cap restarts
    // If we want to mint 500 to a user, the value we use here is 500, then 500 are given to that user and 500 are given to Numerai, so if you want to mint the cap you'll need to use cap / 2 as the value or 25k [because an additional 25k go to Numerai itself]
    function mint(address _to, uint256 _value) onlymanyowners(sha3(msg.data)) returns (bool ok) {
        // Recipient cannot be Numerai.
        if (isOwner(_to) || _to == numerai) throw;

        // Prevent overflows.
        if (!safeToAdd(balance_of[_to], _value)) throw;
        if (!safeToAdd(balance_of[numerai], _value)) throw;
        if (!safeToMultiply(_value, 2)) throw;
        if (!safeToAdd(total_supply, _value*2)) throw;
        if (!safeToSubtract(disbursement, _value*2)) throw;

        // Prevent minting more than the supply cap.
        if ((total_supply + (_value * 2)) > supply_cap) throw;

        // Replenish disbursement a maximum of once per week.
        if (block.timestamp > disbursement_end_time) {
            disbursement_end_time = block.timestamp + disbursement_period;
            disbursement = disbursement_cap;
        }

        // Prevent minting more than the disbursement.
        if ((_value * 2) > disbursement) throw;

        // Numerai receives an amount equal to winner's amount.
        disbursement -= _value * 2;
        balance_of[_to] += _value;
        balance_of[numerai] += _value;
        total_supply += _value * 2;

        // Notify anyone listening.
        Mint(_to, _value);

        return true;
    }

    // Release staked tokens if the user's predictions were successful.
    // _to is the address of the user whose stake we're releasing
    function releaseStake(address _to, uint256 timestamp) onlymanyowners(sha3(msg.data)) returns (bool ok) {
        var stake = staked[_to][timestamp];

        if (!safeToSubtract(staked[_to][timestamp], stake)) throw;
        if (!safeToAdd(balance_of[_to], stake)) throw;

        staked[_to][timestamp] -= stake;
        balance_of[_to] += stake;

        return true;
    }

    // Destroy staked tokens if the user's predictions were not successful.
    // _to is the address of the user whose stake we're destroying
    function destroyStake(address _to, uint256 timestamp) onlymanyowners(sha3(msg.data)) returns (bool ok) {
        // Reduce the total supply by the staked amount and destroy the stake.
        if (!safeToSubtract(total_supply, staked[_to][timestamp])) throw;

        total_supply -= staked[_to][timestamp];
        staked[_to][timestamp] = 0;

        return true;
    }

    // Stake NMR
    function stake(address stake_owner, uint256 _value) onlymanyowners(sha3(msg.data)) returns (bool ok) {
        // Numerai cannot stake on itself
        if (isOwner(stake_owner) || stake_owner == numerai) throw;

        // Check for sufficient funds.
        if (balance_of[stake_owner] < _value) throw;

        // Prevent overflows.
        if (staked[stake_owner][block.timestamp] + _value < staked[stake_owner][block.timestamp]) throw;
        if (!safeToAdd(staked[stake_owner][block.timestamp], _value)) throw;
        if (!safeToSubtract(balance_of[stake_owner], _value)) throw;

        balance_of[stake_owner] -= _value;
        staked[stake_owner][block.timestamp] += _value;

        // Notify anyone listening.
        Stake(stake_owner, block.timestamp, _value);

        return true;
    }

    // Send
    function transfer(address _to, uint256 _value) stopInEmergency returns (bool ok) {
        // Check for sufficient funds.
        if (balance_of[msg.sender] < _value) throw;

        // Prevent overflows.
        if (balance_of[_to] + _value < balance_of[_to]) throw;
        if (!safeToAdd(balance_of[_to], _value)) throw;
        if (!safeToSubtract(balance_of[msg.sender], _value)) throw;

        balance_of[msg.sender] -= _value;
        balance_of[_to] += _value;

        // Notify anyone listening.
        Transfer(msg.sender, _to, _value);

        return true;
    }

    // for transferring nmr from numerai account using multisig
    function numeraiTransfer(address _to, uint256 _value) onlymanyowners(sha3(msg.data)) returns(bool ok) {
        // Check for sufficient funds.
        if (balance_of[numerai] < _value) throw;

        // Prevent overflows.
        if (!safeToAdd(balance_of[_to], _value)) throw;
        if (!safeToSubtract(balance_of[numerai], _value)) throw;

        balance_of[numerai] -= _value;
        balance_of[_to] += _value;

        // Notify anyone listening.
        Transfer(numerai, _to, _value);

        return true;
    }

    // Allow other contracts to spend on sender's behalf
    function approve(address _spender, uint256 _value) stopInEmergency returns (bool ok) {
        allowance_of[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    // Send from a contract
    function transferFrom(address _from, address _to, uint256 _value) stopInEmergency returns (bool ok) {
        // Check for sufficient funds.
        if (balance_of[_from] < _value) throw;
        // Prevent overflows.
        if (!safeToAdd(balance_of[_to], _value)) throw;
        // Check for authorization to spend.
        if (allowance_of[_from][msg.sender] < _value) throw;
        if (!safeToSubtract(balance_of[_from], _value)) throw;
        if (!safeToSubtract(allowance_of[_from][msg.sender], _value)) throw;

        balance_of[_from] -= _value;
        allowance_of[_from][msg.sender] -= _value;
        balance_of[_to] += _value;

        // Notify anyone listening.
        Transfer(_from, _to, _value);

        return true;
    }

    // ERC20 interface to read total supply
    function totalSupply() constant returns (uint256 _supply) {
        return total_supply;
    }

    // ERC20 interface to read balance
    function balanceOf(address _owner) constant returns (uint256 _balance) {
        return balance_of[_owner];
    }

    // ERC20 interface to read allowance
    function allowance(address _owner, address _spender) constant returns (uint256 _allowance) {
        return allowance_of[_owner][_spender];
    }

    // Lookup stake using the owner's address and time of the stake.
    function stakeOf(address _owner, uint256 _timestamp) constant returns (uint256 _staked) {
        return staked[_owner][_timestamp];
    }

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
