pragma solidity ^0.4.8;

// This is the contract that will be unchangeable once deployed.  It will call delegate functions in another contract to change state.  The delegate contract is upgradable.

import "contracts/StoppableShareable.sol";
import "contracts/Safe.sol";
import "contracts/NumeraireShared.sol";

contract NumeraireBackend is StoppableShareable, Safe, NumeraireShared {

    address public delegateContract;
    bool contractUpgradable = true;
    address[] public previousDelegates;

    string public standard = "ERC20";
    string public name = "Numeraire";
    string public symbol = "NMR";
    uint256 public decimals = 18;

    event DelegateChanged(address oldAddress, address newAddress);

    function NumeraireBackend(address[] _owners, uint256 _num_required, uint256 _initial_disbursement) StoppableShareable(_owners, _num_required) {
        total_supply = 0;

        // The first disbursement period begins at contract initialization and can be larger than the weekly disbursement cap.
        if (!safeToAdd(block.timestamp, disbursement_period)) throw;
        disbursement_end_time = block.timestamp + disbursement_period;
        disbursement = _initial_disbursement;
    }

    function disbaleContractUpgradability() onlyManyOwners(sha3(msg.data)) returns (bool) {
        if (!contractUpgradable) throw;
        contractUpgradable = false;
    }

    function changeDelegate(address _newDelegate) onlyManyOwners(sha3(msg.data)) returns (bool) {
        if (!contractUpgradable) throw;

        if (_newDelegate != delegateContract) {
            previousDelegates.push(delegateContract);
            var oldDelegate = delegateContract;
            delegateContract = _newDelegate;
            DelegateChanged(oldDelegate, _newDelegate);
            return true;
        }

        return false;
    }

    function mint(uint256 _value) stopInEmergency returns (bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("mint(uint256)")), _value);
    }

    function stake(uint256 _value, uint256 _tournamentID, uint256 _roundID, uint256 _confidence) stopInEmergency returns (bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("stake(uint256,uint256,uint256,uint256)")), _value, _tournamentID, _roundID, _confidence);
    }

    function stakeOnBehalf(address _stake_owner, address _staker, uint256 _value, uint256 _tournamentID, uint256 _roundID, uint256 _confidence) stopInEmergency returns (bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("stakeOnBehalf(address,address,uint256,uint256,uint256,uint256)")), _stake_owner, _staker, _value, _tournamentID, _roundID, _confidence);
    }

    function releaseStake(address _staker, uint256 _etherValue, uint256 _tournamentID, uint256 _roundID, bool _successful) stopInEmergency returns (bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("releaseStake(address,uint256,uint256,uint256,bool)")), _staker, _etherValue, _tournamentID, _roundID, _successful);
    }

    function destroyStake(address _staker, uint256 _tournamentID, uint256 _roundID) stopInEmergency returns (bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("destroyStake(address,uint256,uint256)")), _staker, _tournamentID, _roundID);
    }

    function numeraiTransfer(address _to, uint256 _value) returns(bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("numeraiTransfer(address,uint256)")), _to, _value);
    }

    function transferDeposit(address _from) returns(bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("transferDeposit(address)")), _from);
    }

    function createTournament(uint256 _tournamentID) returns (bool ok) {
        var tournament = tournaments[_tournamentID];
        if (tournament.creationTime != 0) throw; // Already created
        tournament.creationTime = block.timestamp;
        tournament.numRounds = 0;
        return true;
    }

    function createRound(uint256 _tournamentID, uint256 _roundID, uint256 _resolutionTime) returns (bool ok) {
        var tournament = tournaments[_tournamentID];
        var round = tournament.rounds[_roundID];
        if (round.creationTime != 0) throw;
        tournament.roundIDs.push(_roundID);
        round.creationTime = block.timestamp;
        round.resolutionTime = _resolutionTime;
        round.numStakes = 0;
        tournament.numRounds += 1;
        return true;
    }

    function getTournament(uint256 _tournamentID) constant returns (uint256, uint256, uint256[]) {
        var tournament = tournaments[_tournamentID];
        return (tournament.creationTime, tournament.numRounds, tournament.roundIDs);
    }

    function getRound(uint256 _tournamentID, uint256 _roundID) constant returns (uint256, uint256, uint256, address[]) {
        var round = tournaments[_tournamentID].rounds[_roundID];
        return (round.creationTime, round.resolutionTime, round.numStakes, round.stakeAddresses);
    }

    // Lookup stake
    function getStake(uint256 _tournamentID, uint256 _roundID, address _staker) constant returns (uint256[], uint256[], uint256, uint256, bool, bool) {
        var stake = tournaments[_tournamentID].rounds[_roundID].stakes[_staker];
        return (stake.amounts, stake.timestamps, stake.confidence, stake.amount, stake.successful, stake.resolved);
    }

    // ERC20: Send from a contract
    function transferFrom(address _from, address _to, uint256 _value) stopInEmergency returns (bool ok) {
        if (isOwner(_from) || _from == numerai) throw; // Transfering from Numerai can only be done with the numeraiTransfer function

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
