pragma solidity ^0.4.11;

// This is the contract that will be unchangeable once deployed.  It will call delegate functions in another contract to change state.  The delegate contract is upgradable.

import "contracts/StoppableShareable.sol";
import "contracts/NumeraireShared.sol";

contract NumeraireBackend is StoppableShareable, NumeraireShared {

    address public delegateContract;
    bool public contractUpgradable = true;
    address[] public previousDelegates;

    string public standard = "ERC20";

    // ERC20 requires name, symbol, and decimals
    string public name = "Numeraire";
    string public symbol = "NMR";
    uint256 public decimals = 18;

    event DelegateChanged(address oldAddress, address newAddress);

    function NumeraireBackend(address[] _owners, uint256 _num_required, uint256 _initial_disbursement) StoppableShareable(_owners, _num_required) {
        totalSupply = 0;
        total_minted = 0;

        initial_disbursement = _initial_disbursement;
        deploy_time = block.timestamp;
    }

    function disableContractUpgradability() onlyManyOwners(sha3(msg.data)) returns (bool) {
        assert(contractUpgradable);
        contractUpgradable = false;
    }

    function changeDelegate(address _newDelegate) onlyManyOwners(sha3(msg.data)) returns (bool) {
        assert(contractUpgradable);

        if (_newDelegate != delegateContract) {
            previousDelegates.push(delegateContract);
            var oldDelegate = delegateContract;
            delegateContract = _newDelegate;
            DelegateChanged(oldDelegate, _newDelegate);
            return true;
        }

        return false;
    }

    function claimTokens(address _token) onlyOwner {
        assert(_token != numerai);
        if (_token == 0x0) {
            msg.sender.transfer(this.balance);
            return;
        }

        NumeraireBackend token = NumeraireBackend(_token);
        uint256 balance = token.balanceOf(this);
        token.transfer(msg.sender, balance);
    }

    function mint(uint256 _value) stopInEmergency returns (bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("mint(uint256)")), _value);
    }

    function stake(uint256 _value, bytes32 _tag, uint256 _tournamentID, uint256 _roundID, uint256 _confidence) stopInEmergency returns (bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("stake(uint256,bytes32,uint256,uint256,uint256)")), _value, _tag, _tournamentID, _roundID, _confidence);
    }

    function stakeOnBehalf(address _staker, uint256 _value, bytes32 _tag, uint256 _tournamentID, uint256 _roundID, uint256 _confidence) stopInEmergency onlyPayloadSize(6) returns (bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("stakeOnBehalf(address,uint256,bytes32,uint256,uint256,uint256)")), _staker, _value, _tag, _tournamentID, _roundID, _confidence);
    }

    function releaseStake(address _staker, bytes32 _tag, uint256 _etherValue, uint256 _tournamentID, uint256 _roundID, bool _successful) stopInEmergency onlyPayloadSize(6) returns (bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("releaseStake(address,bytes32,uint256,uint256,uint256,bool)")), _staker, _tag, _etherValue, _tournamentID, _roundID, _successful);
    }

    function destroyStake(address _staker, bytes32 _tag, uint256 _tournamentID, uint256 _roundID) stopInEmergency onlyPayloadSize(4) returns (bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("destroyStake(address,bytes32,uint256,uint256)")), _staker, _tag, _tournamentID, _roundID);
    }

    function numeraiTransfer(address _to, uint256 _value) onlyPayloadSize(2) returns(bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("numeraiTransfer(address,uint256)")), _to, _value);
    }

    function withdraw(address _from, address _to, uint256 _value) onlyPayloadSize(3) returns(bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("withdraw(address,address,uint256)")), _from, _to, _value);
    }

    function createTournament(uint256 _tournamentID) returns (bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("createTournament(uint256)")), _tournamentID);
    }

    function createRound(uint256 _tournamentID, uint256 _roundID, uint256 _endTime, uint256 _resolutionTime) returns (bool ok) {
        return delegateContract.delegatecall(bytes4(sha3("createRound(uint256,uint256,uint256,uint256)")), _tournamentID, _roundID, _endTime, _resolutionTime);
    }

    function getTournament(uint256 _tournamentID) constant returns (uint256, uint256[]) {
        var tournament = tournaments[_tournamentID];
        return (tournament.creationTime, tournament.roundIDs);
    }

    function getRound(uint256 _tournamentID, uint256 _roundID) constant returns (uint256, uint256, uint256) {
        var round = tournaments[_tournamentID].rounds[_roundID];
        return (round.creationTime, round.endTime, round.resolutionTime);
    }

    function getStake(uint256 _tournamentID, uint256 _roundID, address _staker, bytes32 _tag) constant returns (uint256, uint256, bool, bool) {
        var stake = tournaments[_tournamentID].rounds[_roundID].stakes[_staker][_tag];
        return (stake.confidence, stake.amount, stake.successful, stake.resolved);
    }

    // ERC20: Send from a contract
    function transferFrom(address _from, address _to, uint256 _value) stopInEmergency onlyPayloadSize(3) returns (bool ok) {
        require(!isOwner(_from) && _from != numerai); // Transfering from Numerai can only be done with the numeraiTransfer function

        // Check for sufficient funds.
        require(balanceOf[_from] >= _value);
        // Check for authorization to spend.
        require(allowance[_from][msg.sender] >= _value);

        balanceOf[_from] = safeSubtract(balanceOf[_from], _value);
        allowance[_from][msg.sender] = safeSubtract(allowance[_from][msg.sender], _value);
        balanceOf[_to] = safeAdd(balanceOf[_to], _value);

        // Notify anyone listening.
        Transfer(_from, _to, _value);

        return true;
    }

    // ERC20: Anyone with NMR can transfer NMR
    function transfer(address _to, uint256 _value) stopInEmergency onlyPayloadSize(2) returns (bool ok) {
        // Check for sufficient funds.
        require(balanceOf[msg.sender] >= _value);

        balanceOf[msg.sender] = safeSubtract(balanceOf[msg.sender], _value);
        balanceOf[_to] = safeAdd(balanceOf[_to], _value);

        // Notify anyone listening.
        Transfer(msg.sender, _to, _value);

        return true;
    }

    // ERC20: Allow other contracts to spend on sender's behalf
    function approve(address _spender, uint256 _value) stopInEmergency onlyPayloadSize(2) returns (bool ok) {
        require((_value == 0) || (allowance[msg.sender][_spender] == 0));
        allowance[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function changeApproval(address _spender, uint256 _oldValue, uint256 _newValue) stopInEmergency onlyPayloadSize(3) returns (bool ok) {
        require(allowance[msg.sender][_spender] == _oldValue);
        allowance[msg.sender][_spender] = _newValue;
        Approval(msg.sender, _spender, _newValue);
        return true;
    }
}
