pragma solidity ^0.4.11;

import "contracts/StoppableShareable.sol";
import "contracts/NumeraireShared.sol";

// Whoever creates the contract has the power to stop it, this person can be changed via transferOwnership(_new_address)
contract NumeraireDelegate is StoppableShareable, NumeraireShared {

    function NumeraireDelegate(address[] _owners, uint256 _num_required) StoppableShareable(_owners, _num_required) {
    }

    // All minted NMR are initially sent to Numerai, obeying both weekly and total supply caps
    function mint(uint256 _value) onlyOwner returns (bool ok) {
        // Prevent minting more than the supply cap.
        require(safeAdd(total_minted, _value) <= supply_cap);

        // Prevent minting more than the disbursement.
        require(_value <= getMintable());

        balanceOf[numerai] = safeAdd(balanceOf[numerai], _value);
        totalSupply = safeAdd(totalSupply, _value);
        total_minted = safeAdd(total_minted, _value);

        // Notify anyone listening.
        Mint(_value);

        return true;
    }

    // Numerai calls this function to release staked tokens when the staked predictions were successful
    function releaseStake(address _staker, bytes32 _tag, uint256 _etherValue, uint256 _tournamentID, uint256 _roundID, bool _successful) onlyOwner stopInEmergency returns (bool ok) {
        var round = tournaments[_tournamentID].rounds[_roundID];
        var stake = round.stakes[_staker][_tag];
        var originalStakeAmount = stake.amount;

        require(stake.amount > 0);
        require(!stake.resolved);
        require(round.resolutionTime <= block.timestamp);

        stake.amount = 0;
        balanceOf[_staker] = safeAdd(balanceOf[_staker], originalStakeAmount);
        stake.resolved = true;
        stake.successful = _successful;

        if (_etherValue > 0) {
            if (!_staker.send(_etherValue)) {
                stake.amount = originalStakeAmount;
                balanceOf[_staker] -= originalStakeAmount; // safe because we just added it
                stake.resolved = false;
                stake.successful = false;
                return false;
            }
        }

        StakeReleased(_tournamentID, _roundID, _staker, _tag, _etherValue);
        return true;
    }

    // Destroy staked tokens if the predictions were not successful
    function destroyStake(address _staker, bytes32 _tag, uint256 _tournamentID, uint256 _roundID) onlyOwner stopInEmergency returns (bool ok) {
        var round = tournaments[_tournamentID].rounds[_roundID];
        var stake = round.stakes[_staker][_tag];
        var originalStakeAmount = stake.amount;

        require(stake.amount > 0);
        require(!stake.resolved);
        require(round.resolutionTime <= block.timestamp);

        stake.amount = 0;
        totalSupply = safeSubtract(totalSupply, originalStakeAmount);
        stake.resolved = true;
        stake.successful = false;

        StakeDestroyed(_tournamentID, _roundID, _staker, _tag);
        return true;
    }

    // Anyone but Numerai can stake on themselves
    function stake(uint256 _value, bytes32 _tag, uint256 _tournamentID, uint256 _roundID, uint256 _confidence) stopInEmergency returns (bool ok) {
        return _stake(msg.sender, _value, _tag, _tournamentID, _roundID, _confidence);
    }

    // Only Numerai can stake on behalf of other accounts. _stake_owner will always be Numerai's hot wallet
    function stakeOnBehalf(address _staker, uint256 _value, bytes32 _tag, uint256 _tournamentID, uint256 _roundID, uint256 _confidence) onlyOwner stopInEmergency returns (bool ok) {
        var max_deposit_address = 1000000;
        require(_staker <= max_deposit_address);
        return _stake(_staker, _value, _tag, _tournamentID, _roundID, _confidence);
    }

    function _stake(address _staker, uint256 _value, bytes32 _tag, uint256 _tournamentID, uint256 _roundID, uint256 _confidence) stopInEmergency internal returns (bool ok) {
        var tournament = tournaments[_tournamentID];
        var round = tournament.rounds[_roundID];
        var stake = round.stakes[_staker][_tag];

        require(!isOwner(_staker) && _staker != numerai); // Numerai cannot stake on itself
        require(balanceOf[_staker] >= _value); // Check for sufficient funds
        require(tournament.creationTime > 0); // This tournament must be initialized
        require(round.creationTime > 0); // This round must be initialized
        require(round.endTime > block.timestamp); // Can't stake after round ends
        require(_value > 0 || stake.amount > 0); // Can't stake zero NMR

        require(stake.confidence == 0 || stake.confidence <= _confidence);

        // Keep these two lines together so that the Solidity optimizer can
        // merge them into a single SSTORE.
        stake.amount = shrink128(safeAdd(stake.amount, _value));
        stake.confidence = shrink128(_confidence);

        balanceOf[_staker] = safeSubtract(balanceOf[_staker], _value);

        // Notify anyone listening.
        Staked(_staker, _tag, stake.amount, stake.confidence, _tournamentID, _roundID);

        return true;
    }

    // Transfer NMR from Numerai account using multisig
    function numeraiTransfer(address _to, uint256 _value) onlyManyOwners(sha3(msg.data)) returns (bool ok) {
        // Check for sufficient funds.
        require(balanceOf[numerai] >= _value);

        balanceOf[numerai] = safeSubtract(balanceOf[numerai], _value);
        balanceOf[_to] = safeAdd(balanceOf[_to], _value);

        // Notify anyone listening.
        Transfer(numerai, _to, _value);

        return true;
    }

    // Allows Numerai to withdraw on behalf of a data scientist some NMR that they've deposited into a pre-assigned address
    // Numerai will assign these addresses on its website
    function withdraw(address _from, address _to, uint256 _value) onlyOwner returns(bool ok) {
        address max_deposit_address = 1000000;
        require(_from <= max_deposit_address);

        // Identical to transfer(), except msg.sender => _from
        require(balanceOf[_from] >= _value);

        balanceOf[_from] = safeSubtract(balanceOf[_from], _value);
        balanceOf[_to] = safeAdd(balanceOf[_to], _value);

        Transfer(_from, _to, _value);

        return true;
    }

    function createTournament(uint256 _tournamentID) returns (bool ok) {
        var tournament = tournaments[_tournamentID];
        require(tournament.creationTime == 0); // Already created
        tournament.creationTime = block.timestamp;
        TournamentCreated(_tournamentID);
        return true;
    }

    function createRound(uint256 _tournamentID, uint256 _roundID, uint256 _endTime, uint256 _resolutionTime) returns (bool ok) {
        var tournament = tournaments[_tournamentID];
        var round = tournament.rounds[_roundID];
        require(_endTime <= _resolutionTime);
        require(tournament.creationTime > 0);
        require(round.creationTime == 0);
        tournament.roundIDs.push(_roundID);
        round.creationTime = block.timestamp;
        round.endTime = _endTime;
        round.resolutionTime = _resolutionTime;
        RoundCreated(_tournamentID, _roundID, round.endTime, round.resolutionTime);
        return true;
    }
}
