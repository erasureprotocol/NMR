pragma solidity ^0.4.8;

import "contracts/StoppableShareable.sol";
import "contracts/DestructibleShareable.sol";
import "contracts/Safe.sol";
import "contracts/NumeraireShared.sol";

// Whoever creates the contract has the power to stop it, this person can be changed via transferOwnership(_new_address)
contract NumeraireDelegate is StoppableShareable, DestructibleShareable, Safe, NumeraireShared {

    function NumeraireDelegate(address[] _owners, uint256 _num_required) StoppableShareable(_owners, _num_required) DestructibleShareable(_owners, _num_required) {
    }

    // All minted NMR are initially sent to Numerai, obeying both weekly and total supply caps
    function mint(uint256 _value) onlyOwner returns (bool ok) {
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

    // Numerai calls this function to release staked tokens when the staked predictions were successful
    function releaseStake(address _staker, uint256 _etherValue, uint256 _tournamentID, uint256 _roundID, bool _successful) onlyOwner stopInEmergency returns (bool ok) {
        var round = tournaments[_tournamentID].rounds[_roundID];
        var stake = round.stakes[_staker];
        var originalStakeAmount = stake.amount;

        if (stake.amount <= 0) throw;
        if (stake.resolved) throw;
        if (round.resolutionTime > block.timestamp) throw;
        if (!safeToAdd(balance_of[numerai], stake.amount)) throw;

        stake.amount = 0;
        balance_of[_staker] += originalStakeAmount;
        stake.resolved = true;
        stake.successful = _successful;

        if (_etherValue > 0) {
            if (!_staker.send(_etherValue)) {
                stake.amount += originalStakeAmount;
                balance_of[_staker] -= originalStakeAmount;
                stake.resolved = false;
                stake.successful = false;
                return false;
            }
        }

        StakeReleased(_tournamentID, _roundID, _staker, _etherValue);
        return true;
    }

    // Destroy staked tokens if the predictions were not successful
    function destroyStake(address _staker, uint256 _tournamentID, uint256 _roundID) onlyOwner stopInEmergency returns (bool ok) {
        var round = tournaments[_tournamentID].rounds[_roundID];
        var stake = round.stakes[_staker];
        var originalStakeAmount = stake.amount;

        if (stake.amount <= 0) throw;
        if (stake.resolved) throw;
        if (round.resolutionTime > block.timestamp) throw;
        if (!safeToSubtract(total_supply, stake.amount)) throw;

        stake.amount = 0;
        total_supply -= originalStakeAmount;
        stake.resolved = true;
        stake.successful = false;

        StakeDestroyed(_tournamentID, _roundID, _staker);
        return true;
    }

    // Anyone but Numerai can stake on themselves
    function stake(uint256 _value, uint256 _tournamentID, uint256 _roundID, uint256 _confidence) stopInEmergency returns (bool ok) {
        return _stake(msg.sender, msg.sender, _value, _tournamentID, _roundID, _confidence);
    }

    // Only Numerai can stake on behalf of other accounts. _stake_owner will always be Numerai's hot wallet
    function stakeOnBehalf(address _stake_owner, address _staker, uint256 _value, uint256 _tournamentID, uint256 _roundID, uint256 _confidence) onlyOwner stopInEmergency returns (bool ok) {
        return _stake(_stake_owner, _staker, _value, _tournamentID, _roundID, _confidence);
    }

    function _stake(address _from, address _to, uint256 _value, uint256 _tournamentID, uint256 _roundID, uint256 _confidence) stopInEmergency internal returns (bool ok) {
        var tournament = tournaments[_tournamentID];
        var round = tournament.rounds[_roundID];
        var stake = round.stakes[_to];

        if (isOwner(_from) || _from == numerai) throw; // Numerai cannot stake on itself
        if (isOwner(_to) || _to == numerai) throw;
        if (balance_of[_from] < _value) throw; // Check for sufficient funds
        if (tournament.creationTime <= 0) throw; // This tournament must be initialized
        if (round.creationTime <= 0) throw; // This round must be initialized
        if (round.resolutionTime <= block.timestamp) throw; // Can't stake after round ends

        // Prevent overflows.
        if (!safeToAdd(round.numStakes, 1)) throw;
        if (!safeToAdd(stake.amount, _value)) throw;
        if (!safeToSubtract(balance_of[_from], _value)) throw;

        if (stake.confidence == 0) {
            stake.confidence = _confidence;
        }
        else if (stake.confidence <= _confidence) {
            stake.confidence = _confidence;
        }
        else {
            throw; // Confidence can only increased or set to the same, non-zero number
        }

        round.stakeAddresses.push(_to);
        round.numStakes += 1;
        stake.amount += _value;
        balance_of[_from] -= _value;
        stake.timestamps.push(block.timestamp);
        stake.amounts.push(_value);

        // Notify anyone listening.
        StakeCreated(_to, stake.amount, _tournamentID, _roundID);

        return true;
    }

    // Transfer NMR from Numerai account using multisig
    function numeraiTransfer(address _to, uint256 _value) onlyManyOwners(sha3(msg.data)) returns (bool ok) {
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

    // Allows Numerai to withdraw on behalf of a data scientist some NMR that they've deposited into a pre-assigned address
    // Numerai will assign these addresses on its website
    function transferDeposit(address from) onlyOwner returns(bool ok) {
        var max_deposit_address = 1000000;
        if (from > max_deposit_address) throw;
        if (balance_of[from] == 0) throw;

        if (!safeToSubtract(balance_of[numerai], balance_of[from])) throw;
        balance_of[numerai] += balance_of[from];
        balance_of[from] = 0;

        return true;
    }

}
