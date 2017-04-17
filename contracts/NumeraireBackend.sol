pragma solidity ^0.4.10;

// This is the contract that will be unchangeable once deployed.  It will call delegate functions in another contract to change state.  The delegate contract is upgradable.

import "StoppableShareable.sol";
import "Safe.sol";
import "NumeraireShared.sol";

contract NumeraireBackend is StoppableShareable, Safe, NumeraireShared {

    address public backendContract;
    bool upgradable = true;
    address[] public previousBackends;

    string public standard = "ERC20";
    string public name = "Numeraire";
    string public symbol = "NMR";
    uint256 public decimals = 18;

    address public numerai = this;

    function NumeraireBackend(address[] _owners, uint256 _num_required, uint256 _initial_disbursement) StoppableShareable(_owners, _num_required) {
        total_supply = 0;

        // The first disbursement period begins at contract initialization and can be larger than the weekly disbursement cap.
        if (!safeToAdd(block.timestamp, disbursement_period)) throw;
        disbursement_end_time = block.timestamp + disbursement_period;
        disbursement = _initial_disbursement;
    }

    function disbaleUpgradability() onlyManyOwners(sha3(msg.data)) returns (bool) {
        if (!upgradable) throw;
        upgradable = false;
    }

    function changeBackend(address newBackend) onlyOwner() returns (bool) {
        if (!upgradable) throw;

        if (newBackend != backendContract) {
            previousBackends.push(backendContract);
            backendContract = newBackend;
            return true;
        }

        return false;
    }

    function mint(uint256 _value) stopInEmergency returns (bool ok) {
        return backendContract.delegatecall(bytes4(sha3("mint(uint256)")), _value);
    }

    function stake(address stake_owner, bytes32 _submissionID, uint256 _value) stopInEmergency returns (bool ok) {
        return backendContract.delegatecall(bytes4(sha3("stake(address, bytes32, uint256)")), stake_owner, _submissionID, _value);
    }

    function releaseStake(bytes32 _submissionID) stopInEmergency returns (bool ok) {
        return backendContract.delegatecall(bytes4(sha3("releaseStake(bytes32)")), _submissionID);
    }

    function destroyStake(bytes32 _submissionID) stopInEmergency returns (bool ok) {
        return backendContract.delegatecall(bytes4(sha3("destroyStake(bytes32)")), _submissionID);
    }

    function numeraiTransfer(address _to, uint256 _value) returns(bool ok) {
        return backendContract.delegatecall(bytes4(sha3("numeraiTransfer(address, uint256)")), _to, _value);
    }

    // ERC20: Send from a contract
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

    // ERC20: Anyone with NMR can transfer NMR
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

    // ERC20: Allow other contracts to spend on sender's behalf
    function approve(address _spender, uint256 _value) stopInEmergency returns (bool ok) {
        allowance_of[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
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
}
