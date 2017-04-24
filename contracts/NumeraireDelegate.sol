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
    function releaseStake(address _staker, uint256 _timestamp, uint256 _etherValue, uint256 _tournament) onlyOwner stopInEmergency returns (bool ok) {
        var stake = staked[_tournament][_staker][_timestamp];
        if (stake == 0) throw;

        Mint(_timestamp);
        Mint(resolution_period);
        Mint(block.timestamp);
        if ((_timestamp + resolution_period) > block.timestamp) throw;

        if (!safeToSubtract(staked[_tournament][_staker][_timestamp], stake)) throw;
        if (!safeToAdd(balance_of[numerai], stake)) throw;

        staked[_tournament][_staker][_timestamp] -= stake;
        balance_of[numerai] += stake;
        if (_etherValue > 0) {
            if (!_staker.send(_etherValue)) {
                staked[_tournament][_staker][_timestamp] += stake;
                balance_of[numerai] -= stake;
                return false;
            }
        }
        return true;
    }

    // Destroy staked tokens if the predictions were not successful
    function destroyStake(address _staker, uint256 _timestamp, uint256 _tournament) onlyOwner stopInEmergency returns (bool ok) {
        var stake = staked[_tournament][_staker][_timestamp];
        if(stake == 0) {
          throw;
        }

        // Reduce the total supply by the staked amount and destroy the stake.
        if (!safeToSubtract(total_supply, staked[_tournament][_staker][_timestamp])) throw;

        total_supply -= staked[_tournament][_staker][_timestamp];
        staked[_tournament][_staker][_timestamp] = 0;

        return true;
    }

    // Anyone but Numerai can stake on themselves
    function stake(uint256 _value, uint256 _tournament) stopInEmergency returns (bool ok) {
        // Numerai cannot stake on itself
        if (isOwner(msg.sender) || msg.sender == numerai) throw;

        // Check for sufficient funds.
        if (balance_of[msg.sender] < _value) throw;

        // Prevent overflows.
        if (staked[_tournament][msg.sender][block.timestamp] + _value < staked[_tournament][msg.sender][block.timestamp]) throw;
        if (!safeToAdd(staked[_tournament][msg.sender][block.timestamp], _value)) throw;
        if (!safeToSubtract(balance_of[msg.sender], _value)) throw;

        balance_of[msg.sender] -= _value;
        staked[_tournament][msg.sender][block.timestamp] += _value;

        // Notify anyone listening.
        Stake(msg.sender, _value, _tournament);

        return true;
    }

    // Only Numerai can stake on behalf of other accounts. _stake_owner will always be Numeari's hot wallet
    function stakeOnBehalf(address _stake_owner, address _staker, uint256 _value, uint256 _tournament) onlyOwner stopInEmergency returns (bool ok) {
        // Numerai cannot stake on itself
        if (isOwner(_stake_owner) || _stake_owner == numerai) throw;

        // Check for sufficient funds.
        if (balance_of[_stake_owner] < _value) throw;

        // Prevent overflows.
        if (staked[_tournament][_staker][block.timestamp] + _value < staked[_tournament][_staker][block.timestamp]) throw;
        if (!safeToAdd(staked[_tournament][_staker][block.timestamp], _value)) throw;
        if (!safeToSubtract(balance_of[_stake_owner], _value)) throw;

        balance_of[_stake_owner] -= _value;
        staked[_tournament][_staker][block.timestamp] += _value;

        // Notify anyone listening.
        Stake(_staker, _value, _tournament);

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
