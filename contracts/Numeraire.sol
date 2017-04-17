pragma solidity ^0.4.10;

import "Numeraire_dependencies.sol";

// Whoever creates the contract has the power to stop it, this person can be changed via transferOwnership(_new_address)
contract Numeraire is Stoppable, Sharable {

    string public standard = "ERC20";
    string public name = "Numeraire";
    string public symbol = "NMR";
    uint256 public decimals = 18;

    address public numerai = this;

    // Cap the total supply at and the weekly supply
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
    // Can mint multiple times per week, just can't mint more than the cap in a week, then next week the cap restarts
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
        if(stake == 0) {
          throw;
        }

        if (!safeToSubtract(staked[_to][timestamp], stake)) throw;
        if (!safeToAdd(balance_of[_to], stake)) throw;

        staked[_to][timestamp] -= stake;
        balance_of[_to] += stake;

        return true;
    }

    // Destroy staked tokens if the user's predictions were not successful.
    // _to is the address of the user whose stake we're destroying
    function destroyStake(address _to, uint256 timestamp) onlymanyowners(sha3(msg.data)) returns (bool ok) {
        var stake = staked[_to][timestamp];
        if(stake == 0) {
          throw;
        }

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
