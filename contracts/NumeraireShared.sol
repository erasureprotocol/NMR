pragma solidity ^0.4.8;

import "contracts/Safe.sol";

// Class variables used both in NumeraireBackend and NumeraireDelegate

contract NumeraireShared is Safe {

    address public numerai = this;

    // Cap the total supply and the weekly supply
    uint256 public supply_cap = 21000000000000000000000000; // 21 million
    uint256 public weekly_disbursement = 96153846153846153846153;

    uint256 public initial_disbursement;
    uint256 public deploy_time;

    uint256 public total_minted;
    uint256 public total_supply;

    mapping (address => uint256) public balance_of;
    mapping (address => mapping (address => uint256)) public allowance_of;
    mapping (uint => Tournament) public tournaments;  // tournamentID

    struct Tournament {
        uint256 creationTime;
        uint256 numRounds;
        uint256[] roundIDs;
        mapping (uint256 => Round) rounds;  // roundID
    } 

    struct Round {
        uint256 creationTime;
        uint256 resolutionTime;
        uint256 numStakes;
        address[] stakeAddresses;
        mapping (address => Stake) stakes;  // address of staker
    }

    struct Stake {
        uint256[] amounts;
        uint256[] confidences;
        uint256[] timestamps;
        uint256 amount; // Once the stake is resolved, this becomes 0
        uint256 confidence;
        bool successful;
        bool resolved;
    }

    // Generates a public event on the blockchain to notify clients
    event Mint(uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event StakeCreated(address indexed staker, uint256 totalAmountStaked, uint256 indexed tournamentID, uint256 indexed roundID);
    event RoundCreated(uint256 indexed tournamentID, uint256 indexed roundID, uint256 resolutionTime);
    event TournamentCreated(uint256 indexed tournamentID);
    event StakeDestroyed(uint256 indexed tournamentID, uint256 indexed roundID, address indexed stakerAddress);
    event StakeReleased(uint256 indexed tournamentID, uint256 indexed roundID, address indexed stakerAddress, uint256 etherReward);

    // Calculate allowable disbursement
    function getMintable() constant returns (uint256) {
        if (!safeToSubtract(block.timestamp, deploy_time)) throw;
        uint256 time_delta = (block.timestamp - deploy_time);
        if (!safeToMultiply(weekly_disbursement, time_delta)) throw;
        uint256 incremental_allowance = (weekly_disbursement * time_delta) / 1 weeks;
        if (!safeToAdd(initial_disbursement, incremental_allowance)) throw;
        uint256 total_allowance = initial_disbursement + incremental_allowance;
        if (!safeToSubtract(total_allowance, total_minted)) throw;
        return total_allowance - total_minted;
    }

}
