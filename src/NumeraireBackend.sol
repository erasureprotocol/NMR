pragma solidity ^0.4.8;

// This is the contract that will be unchangeable once deployed.  It will call delegate functions in another contract to change state.  The delegate contract is upgradable.
import "ds-token/base.sol";
import "ds-math/math.sol";
import "ds-auth/auth.sol";

import "./NumeraireShared.sol";
import "./Stoppable.sol";


contract NumeraireBackend is DSAuth, DSMath, DSTokenBase(0), Stoppable, NumeraireShared  {

    address public delegateContract;
    bool upgradable = true;
    address[] public previousDelegates;

    string public standard = "ERC20";
    string public name = "Numeraire";
    string public symbol = "NMR";
    uint256 public decimals = 18;

    event DelegateChanged(address oldAddress, address newAddress);

    function NumeraireBackend(uint256 _initial_disbursement) {

        // The first disbursement period begins at contract initialization and can be larger than the weekly disbursement cap.
        add(block.timestamp, disbursement_period);

        disbursement_end_time = block.timestamp + disbursement_period;
        disbursement = _initial_disbursement;
    }

    function disableUpgradability() auth returns (bool) {
        if (!upgradable) throw;
        upgradable = false;
    }

    function changeDelegate(address newDelegate) auth returns (bool) {
        if (!upgradable) throw;

        if (newDelegate != delegateContract) {
            previousDelegates.push(delegateContract);
            delegateContract = newDelegate;
            DelegateChanged(delegateContract, newDelegate);
            return true;
        }

        return false;
    }

    function mint(uint256 _value) stopInEmergency returns (bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("mint(uint256)")), _value);
    }

    function stake(address stake_owner, bytes32 _submissionID, uint256 _value) stopInEmergency returns (bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("stake(address,bytes32,uint256)")), stake_owner, _submissionID, _value);
    }

    function releaseStake(bytes32 _submissionID) stopInEmergency returns (bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("releaseStake(bytes32)")), _submissionID);
    }

    function destroyStake(bytes32 _submissionID) stopInEmergency returns (bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("destroyStake(bytes32)")), _submissionID);
    }

    function numeraiTransfer(address _to, uint256 _value) returns(bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("numeraiTransfer(address,uint256)")), _to, _value);
    }

    // Lookup stake
    function stakeOf(bytes32 _submissionID) constant returns (uint256 _staked) {
        return staked[_submissionID];
    }
}
