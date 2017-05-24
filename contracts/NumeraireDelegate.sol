pragma solidity ^0.4.8;

import "contracts/StoppableShareable.sol";
import "contracts/DestructibleShareable.sol";
import "contracts/NumeraireShared.sol";

// Whoever creates the contract has the power to stop it, this person can be changed via transferOwnership(_new_address)
contract NumeraireDelegate is StoppableShareable, DestructibleShareable, NumeraireShared {

    function NumeraireDelegate(address[] _owners, uint256 _num_required) StoppableShareable(_owners, _num_required) DestructibleShareable(_owners, _num_required) {
    }

    // All minted NMR are initially sent to Numerai, obeying both weekly and total supply caps
    function mint(uint256 _value) onlyOwner returns (bool ok) {
        // Prevent overflows.
        if (!safeToAdd(balance_of[numerai], _value)) throw;
        if (!safeToAdd(total_supply, _value)) throw;
        if (!safeToAdd(total_minted, _value)) throw;

        // Prevent minting more than the supply cap.
        if ((total_minted + _value) > supply_cap) throw;

        // Prevent minting more than the disbursement.
        if (_value > getMintable()) throw;

        balance_of[numerai] += _value;
        total_supply += _value;
        total_minted += _value;

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
        return _stake(msg.sender, _value, _tournamentID, _roundID, _confidence);
    }

    // Only Numerai can stake on behalf of other accounts. _stake_owner will always be Numerai's hot wallet
    function stakeOnBehalf(address _staker, uint256 _value, uint256 _tournamentID, uint256 _roundID, uint256 _confidence) onlyOwner stopInEmergency returns (bool ok) {
        var max_deposit_address = 1000000;
        if (_staker > max_deposit_address) throw;
        return _stake(_staker, _value, _tournamentID, _roundID, _confidence);
    }

    function _stake(address _staker, uint256 _value, uint256 _tournamentID, uint256 _roundID, uint256 _confidence) stopInEmergency internal returns (bool ok) {
        var tournament = tournaments[_tournamentID];
        var round = tournament.rounds[_roundID];
        var stake = round.stakes[_staker];

        if (isOwner(_staker) || _staker == numerai) throw; // Numerai cannot stake on itself
        if (balance_of[_staker] < _value) throw; // Check for sufficient funds
        if (tournament.creationTime <= 0) throw; // This tournament must be initialized
        if (round.creationTime <= 0) throw; // This round must be initialized
        if (round.resolutionTime <= block.timestamp) throw; // Can't stake after round ends
        if (_value <= 0) throw; // Can't stake zero NMR

        // Prevent overflows.
        if (!safeToAdd(stake.amount, _value)) throw;
        if (!safeToSubtract(balance_of[_staker], _value)) throw;

        if (stake.confidence == 0) {
            stake.confidence = _confidence;
        }
        else if (stake.confidence <= _confidence) {
            stake.confidence = _confidence;
        }
        else {
            throw; // Confidence can only increased or set to the same, non-zero number
        }

        if (stake.amount <= 0) {
            round.stakeAddresses.push(_staker);
        }

        stake.amount += _value;
        balance_of[_staker] -= _value;

        // Notify anyone listening.
        Staked(_staker, stake.amount, stake.confidence, _tournamentID, _roundID);

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
    function withdraw(address _from, address _to, uint256 _value) onlyOwner returns(bool ok) {
        var max_deposit_address = 1000000;
        if (_from > max_deposit_address) throw;

        // Identical to transfer(), except msg.sender => _from
        if (balance_of[_from] < _value) throw;

        if (!safeToAdd(balance_of[_to], _value)) throw;
        if (!safeToSubtract(balance_of[_from], _value)) throw;

        balance_of[_from] -= _value;
        balance_of[_to] += _value;

        Transfer(_from, _to, _value);

        return true;
    }
}
