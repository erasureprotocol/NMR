pragma solidity ^0.4.8;


// Class variables used both in NumeraireBackend and NumeraireDelegate

contract NumeraireShared {

    address public numerai = this;

    // Cap the total supply and the weekly supply
    uint256 public supply_max = 21000000000000000000000000; // 21 million
    uint256 public disbursement_cap = 96153846153846153846153;

    uint256 public disbursement_period = 1 weeks;
    uint256 public disbursement_end_time;

    uint256 public disbursement;

    mapping (bytes32 => uint256) public staked; // A map of submissionIDs to NMR values

    // shared data types with the token contract
    uint256 _supply;
    mapping (address => uint256) _balances;

    // Generates a public event on the blockchain to notify clients
    event Mint(uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Stake(bytes32 indexed submissionID, uint256 value);
}
