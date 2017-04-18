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

    // Lookup stake
    function stakeOf(bytes32 _submissionID) constant returns (uint256 _staked) {
        return staked[_submissionID];
    }
}
