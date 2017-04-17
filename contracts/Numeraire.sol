pragma solidity ^0.4.10;

import "StoppableShareable.sol";
import "DestructibleShareable.sol";

// Whoever creates the contract has the power to stop it, this person can be changed via transferOwnership(_new_address)
contract Numeraire is StoppableShareable, DestructibleShareable {

    string public standard = "ERC20";
    string public name = "Numeraire";
    string public symbol = "NMR";
    uint256 public decimals = 18;

    address public numerai = this;

    // Cap the total supply and the weekly supply
    uint256 public supply_cap = 21000000000000000000000000;
    uint256 public disbursement_cap = 96153846153846153846153;

    uint256 public disbursement_period = 1 weeks;
    uint256 public disbursement_end_time;

    uint256 public disbursement;
    uint256 public total_supply;

    mapping (address => uint256) public balance_of;
    mapping (address => mapping (address => uint256)) public allowance_of;
    mapping (bytes32 => uint256) public staked; // A map of submissionIDs to NMR values

    // Generates a public event on the blockchain to notify clients
    event Mint(uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Stake(bytes32 indexed submissionID, uint256 value);

    // Initialization
    // Msg.sender is first owner
    function Numeraire(address[] _owners, uint256 _num_required, uint256 _initial_disbursement) StoppableShareable(_owners, _num_required) DestructibleShareable(_owners, _num_required) {
        total_supply = 0;

        // The first disbursement period begins at contract initialization and can be larger than the weekly disbursement cap.
        if (!safeToAdd(block.timestamp, disbursement_period)) throw;
        disbursement_end_time = block.timestamp + disbursement_period;
        disbursement = _initial_disbursement;
    }

    // All minted NMR are initially sent to Numerai, obeying both weekly and total supply caps
    function mint(uint256 _value) onlyOwner stopInEmergency returns (bool ok) {
        // Prevent overflows.
        if (!safeToSubtract(disbursement, _value)) throw;
        if (!safeToAdd(balance_of[numerai], _value)) throw;
        if (!safeToAdd(total_supply, _value)) throw;

        // Prevent minting more than the supply cap.
        if ((total_supply + _value) > supply_cap) throw;

        // Replenish disbursement a maximum of once per week.
        if (block.timestamp > disbursement_end_time) {
            disbursement_end_time = block.timestamp + disbursement_period;
            disbursement = disbursement_cap;
        }

        // Prevent minting more than the disbursement.
        if (_value > disbursement) throw;

        disbursement -= _value;
        balance_of[numerai] += _value;
        total_supply += _value;

        // Notify anyone listening.
        Mint(_value);

        return true;
    }

    // Release staked tokens if the predictions were successful
    function releaseStake(bytes32 _submissionID) onlyOwner stopInEmergency returns (bool ok) {
        var stake = staked[_submissionID];
        if (stake == 0) {
          throw;
        }

        if (!safeToSubtract(staked[_submissionID], stake)) throw;
        if (!safeToAdd(balance_of[numerai], stake)) throw;

        staked[_submissionID] -= stake;
        balance_of[numerai] += stake;

        return true;
    }

    // Destroy staked tokens if the predictions were not successful
    function destroyStake(bytes32 _submissionID) onlyOwner stopInEmergency returns (bool ok) {
        var stake = staked[_submissionID];
        if(stake == 0) {
          throw;
        }

        // Reduce the total supply by the staked amount and destroy the stake.
        if (!safeToSubtract(total_supply, staked[_submissionID])) throw;

        total_supply -= staked[_submissionID];
        staked[_submissionID] = 0;

        return true;
    }

    // Only Numerai can stake NMR, stake_owner will always be Numeari's hot wallet
    function stake(address stake_owner, bytes32 _submissionID, uint256 _value) onlyOwner stopInEmergency returns (bool ok) {
        // Numerai cannot stake on itself
        if (isOwner(stake_owner) || stake_owner == numerai) throw;

        // Check for sufficient funds.
        if (balance_of[stake_owner] < _value) throw;

        // Prevent overflows.
        if (staked[_submissionID] + _value < staked[_submissionID]) throw;
        if (!safeToAdd(staked[_submissionID], _value)) throw;
        if (!safeToSubtract(balance_of[stake_owner], _value)) throw;

        balance_of[stake_owner] -= _value;
        staked[_submissionID] += _value;

        // Notify anyone listening.
        Stake(_submissionID, _value);

        return true;
    }

    // Anyone with NMR can transfer NMR
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

    // Transfer NMR from Numerai account using multisig
    function numeraiTransfer(address _to, uint256 _value) onlyManyOwners(sha3(msg.data)) returns(bool ok) {
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

    // Lookup stake
    function stakeOf(bytes32 _submissionID) constant returns (uint256 _staked) {
        return staked[_submissionID];
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
