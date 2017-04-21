pragma solidity ^0.4.10;

import "ds-token/base.sol";
import "ds-math/math.sol";

import "./Stoppable.sol";
import "./Destructible.sol";
import "./NumeraireShared.sol";

// Whoever creates the contract has the power to stop it, this person can be changed via transferOwnership(_new_address)
contract NumeraireDelegate is DSAuth, DSMath, Stoppable, Destructible, NumeraireShared {

    event Mint(uint256 value);

    // All minted NMR are initially sent to Numerai, obeying both weekly and total supply caps
    function mint(uint256 _value) auth returns (bool ok) {

        // Prevent minting more than the supply cap.
        assert((_supply + _value) <= supply_max);

        return true;
    }

    // Release staked tokens if the predictions were successful
    function releaseStake(bytes32 _submissionID) auth stopInEmergency returns (bool ok) {

        _balances[numerai] = add(_balances[numerai], staked[_submissionID]);
        staked[_submissionID] = 0;

        return true;
    }

    // Destroy staked tokens if the predictions were not successful
    function destroyStake(bytes32 _submissionID) auth stopInEmergency returns (bool ok) {
        var stake = staked[_submissionID];

        _supply = sub(_supply, stake);
        staked[_submissionID] = 0;

        return true;
    }

    // Only Numerai can stake NMR, stake_owner will always be Numeari's hot wallet
    function stake(address stake_owner, bytes32 _submissionID, uint256 _value) auth stopInEmergency returns (bool ok) {

        // Check for sufficient funds.
        assert(_balances[stake_owner] < _value);

        _balances[stake_owner] = sub(_balances[stake_owner], _value);
        staked[_submissionID] = add(staked[_submissionID], _value);

        // Notify anyone listening.
        Stake(_submissionID, _value);

        return true;
    }

    // Transfer NMR from Numerai account using multisig
    function numeraiTransfer(address _to, uint256 _value) auth returns (bool ok) {
        // Check for sufficient funds.
        assert(_balances[numerai] >= _value);

        _balances[numerai] = sub(_balances[numerai], _value);
        _balances[_to] = add(_balances[_to], _value);

        // Notify anyone listening.
        Transfer(numerai, _to, _value);

        return true;
    }

}
