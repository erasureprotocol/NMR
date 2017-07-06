# Numeraire Ethereum Smart Contract

Numeraire is an [ERC20](https://github.com/ethereum/EIPs/issues/20) token used for staking in [Numerai](https://numer.ai)'s machine learning tournament to solve the stock market.  The token mechanics are described in the [whitepaper](https://numer.ai/whitepaper.pdf).

Authors: [Alex Mingoia](https://github.com/alexmingoia), [Joey Krug](https://github.com/joeykrug), [Xander Dunn](https://github.com/xanderdunn), and [Philip Monk](https://github.com/philipcmonk)

Security Audit: Peter Vessenes and Dennis Peterson at [New Alchemy](https://newalchemy.io/).  See security_audit.pdf.

## Overview
- Should require multi-sig for some functions
- Should be able to single-sig pause the contract and multi-sig unpause the contract
- All state-changing functions should be disabled in the paused state unless it requires multi-sig
- Only Numerai can release stakes, destroy stakes, and mint
- Transfers from Numerai's store of NMR require multi-sig
- All NMR initially minted are sent to Numerai's multi-sig
- The contract should be upgradable so that the maps of balances, allowances, and stakes remain unchanged but the functions called for minting, staking, releasing stakes, and destroying stakes are changed.
- It should be possible to disable upgradability forever
- Any address can stake
- Numerai can make a stake on behalf of addresses 0 through 1,000,000
- Stakes are released to the address that made the stake
- In addition to NMR, ETH can be sent to the address that made the released stake

## Development

### Install
- Clone this repository: `git clone git@github.com:numerai/contract.git && cd contract`
- Install dependencies: `npm install`
- Install truffle: `sudo npm install -g truffle`
- Install testrpc: `sudo npm install -g ethereumjs-testrpc`
- Install solc:
  - On Ubuntu, this is:
    ```
    sudo add-apt-repository ppa:ethereum/ethereum
    sudo apt-get update
    sudo apt-get install solc
    ```
  - On Mac:
    ```
    brew tap ethereum/ethereum
    brew install solidity
    ```


### Compile
- `solc --bin contracts/NumeraireBackend.sol` or `truffle compile`

### Test
- `testrpc -p 6545 -u 0x54fd80d6ae7584d8e9a19fe1df43f04e5282cc43 -u 0xa6d135de4acf44f34e2e14a4ee619ce0a99d1e08` to start the test server with the multi-sig keys unlocked
- `truffle test` to run the tests

## Usage

General notes:
- All values are specified as `uint256` with 18 decimals.
- We throw on error rather than return false.

### User functions

The following are functions that may be useful for a user to call.

#### `transfer(address _to, uint256 _value) stopInEmergency onlyPayloadSize(2)`

Transfers NMR to another user.  This function is part of the ERC20 standard.

- `_to` is the destination address.
- `_value` is the amount to be transferred.

#### `stake(uint256 _value, bytes32 _tag, uint256 _tournamentID, uint256 _roundID, uint256 _confidence)`

Stakes NMR on a prediction.  Users should ensure that their stake is valid
according to the rules set forth [here](https://numer.ai/rules).

- `_value` is the amount to be staked.
- `tag` is used to associate the prediction with a particular submission.
  Currently, the tag should be the username of the web account that made the
  submission.
- `_tournamentID` is the id of the tournament that the round is in.  For now,
  this is always `1`.  
- `_roundID` is the id of the round.
- `_confidence` is the confidence level of the stake with 3 decimals.

#### `approve(address _spender, uint256 _value)`

Allows another contract to spend on user's behalf.  This function is part of the
ERC20 standard.

We recommend to use this function with special care since improper use will
result in vulnerability to [this attack](https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM).
To mitigate this, we require the user set the approval to zero before changing
to another non-zero value.  However, in general, `changeApproval` is much
safer.

- `_spender` is the address of the contract.
- `_value` is the amount to allow the contract to spend.

#### `changeApproval(address _spender, uint256 _oldValue, uint256 _newValue)`

Sets the approval to a new value while checking that the previous approval
value is what we expected.  This is safer than `approve`.

- `_spender` is the address of the contract.
- `_oldValue` is the current amount the contract is allowed to spend.
- `_newValue` is the new amount to allow the contract to spend.

#### `transferFrom(address _from, address _to, uint256 _value)`

Transfers NMR from one address to another.  Called by a contract which has been
approved by `_from` to spend some of its NMR.

- `_from` is the source of the NMR.  It must have already approved the sender
  to spend some of its NMR.
- `_to` is the destination address.
- `_value` is the amount of NMR to transfer.

### Inspection

The following are constant functions (i.e. they don't cause any state change
and may be called without submitting a transaction or paying gas costs).

#### `totalSupply() returns uint256`

Returns the current supply of NMR.  This function is part of the ERC20 standard.

#### `total_minted() returns uint256`

Returns the total NMR ever minted.  This will be more than `totalSupply` stakes
are destroyed.

#### `initial_disbursement() returns uint256`

Returns the amount of NMR disbursed at deploy time.

#### `supply_cap() returns uint256`

Returns 21 million NMR, the total that will ever be minted.

#### `weekly_disbursement() returns uint256`

Returns the amount of NMR permitted to be minted every week.

#### `getMintable() returns uint256`

Returns the amount of the NMR that could be minted now.

#### `deploy_time() returns uint256`

Returns the timestamp of the block when the contract was deployed.

#### `balanceOf(address _user) returns uint256`

Returns the balance of the given address.  This is part of the ERC20 standard.

#### `allowance(address _user, address _contract) returns uint256`

Returns the amount that `_user` has approved for `_contract` to spend.

#### `standard() returns string`

Returns the token standard, which is "ERC20".  This is part of the ERC20
standard.

#### `name() returns string`

Returns the human-readable name of the token, which is "Numeraire".  This is
part of the ERC20 standard.

#### `symbol() returns string`

Returns the human-readable abbreviation of the token, which is "NMR".  This is
part of the ERC20 standard.

#### `decimals() returns uint256`

Returns the number of decimals in the canonical representation of NMR amounts,
which is 18.  This is part of the ERC20 standard.

#### `delegateContract() returns address`

Returns the address of the delegate contract, which is the upgradeable portion
of the contract.

#### `contractUpgradable() returns bool`

Returns whether the contract is still upgradeable.  This can be changed with
`disableContractUpgradability`.

#### `previousDelegates(uint _i) returns address`

Returns the `_i`th previous delegate contract.

#### `getTournament(uint256 _tournamentID) returns (uint256, uint256[])`

Returns the creation time and round list for the given tournament.

#### `getRound(uint256 _tournamentID, uint256 _roundID) returns (uint256, uint256, uint256)`

Returns the creation time, end time, and resolution time for the given round in
the given tournament.

#### `getStake(uint256 _tournamentID, uint256 _roundID, address _staker, bytes32 _tag) returns (uint256, uint256, bool, bool)`

Returns the stake made by `_staker` on user `_tag` in round `_roundID` of
tournament `_tournamentID`.  The result includes the confidence level, stake
amount, success, and whether or not the stake has been resolved yet.

#### `required() returns uint`

Returns the number of contract owner confirmations required for a multi-sig
transaction.

#### `getOwner(uint ownerIndex) returns address`

Returns the owner at the given index.

#### `isOwner(address _addr) returns bool`

Returns true if the address is an owner.

#### `hasConfirmed(bytes32 _operation, address _owner) returns bool`

Returns true if the given address is an owner that has confirmed the given
operation.

#### `stopped() returns bool`

Returns true if the contract is in an emergency stop.

#### `stoppable() returns bool`

Returns true if the contract can be stopped.

### Events

The following events may be emitted by the contract.

#### `Mint(uint256 value)`

Emitted when minting `value` NMR.

#### `Transfer(address indexed from, address indexed to, uint256 value)`

Emitted when NMR is transferred from one address to another.

#### `Approval(address indexed owner, address indexed spender, uint256 value)`

Emitted when a user approves a contract to spend an amount of NMR on their
behalf.

#### `Staked(address indexed staker, bytes32 tag, uint256 totalAmountStaked, uint256 confidence, uint256 indexed tournamentID, uint256 indexed roundID)`

Emitted when a stake is recorded.

#### `TournamentCreated(uint256 indexed tournamentID)`

Emitted when a tournament is created.

#### `RoundCreated(uint256 indexed tournamentID, uint256 indexed roundID, uint256 endTime, uint256 resolutionTime)`

Emitted when a round is created.

#### `StakeReleased(uint256 indexed tournamentID, uint256 indexed roundID, address indexed stakerAddress, bytes32 tag, uint256 etherReward)`

Emitted when a stake is released.

#### `StakeDestroyed(uint256 indexed tournamentID, uint256 indexed roundID, address indexed stakerAddress, bytes32 tag)`

Emitted when a stake is destroyed.

#### `DelegateChanged(address oldAddress, address newAddress)`

Emitted when the delegate address has changed.

#### `Confirmation(address owner, bytes32 operation)`

Emitted when one of the contract owners confirms a multi-sig transaction.

#### `Revoke(address owner, bytes32 operation)`

Emitted when one of the contract owners revokes a previous confirmation of a
multi-sig transaction.

### Owner operations

The following are functions that may only be called by one or more of the
contract owners.

#### `changeDelegate(address _newDelegate)`

Changes the delegate contract.

#### `disableContractUpgradability()`

Permanently disables the changing the delegate contract.

#### `claimTokens(address _token)`

If `_token` is 0, then sends all ether in the contract to the sender.  If
`_token` is the address of an ERC20 token, then this sends all of those tokens
to the sender.

#### `mint(uint256 _value)`

Mints new NMR, depositing it into the balance of the contract.

#### `numeraiTransfer(address _to, uint256 _value)`

Transfers NMR from the contract.

#### `stakeOnBehalf(address _staker, uint256 _value, bytes32 _tag, uint256 _tournamentID, uint256 _roundID, uint256 _confidence)`

Performs a stake on behalf of a Numerai web user's assigned address.  This only
functions when `_staker` is no more than 1 million.

#### `releaseStake(address _staker, bytes32 _tag, uint256 _etherValue, uint256 _tournamentID, uint256 _roundID, bool _successful)`

Releases a stake after the round has resolved.  Sets the stake amount to 0.
Also sends `_etherValue` of ether to the address.

#### `destroyStake(address _staker, bytes32 _tag, uint256 _tournamentID, uint256 _roundID)`

Destroys a stake after the round has resolved.  Sets the stake amount to 0.
The value of the stake is not returned to the staker, and `totalSupply` reduces
by that amount.

#### `withdraw(address _from, address _to, uint256 _value)`

Withdraws NMR from a Numerai web account to another address.  `_from` must be
no more than 1 million.

#### `createTournament(uint256 _tournamentID)`

Creates a tournament with the given ID.

#### `createRound(uint256 _tournamentID, uint256 _roundID, uint256 _endTime, uint256 _resolutionTime)`

Creates a round in the given tournament with the given end time and resolution time.

#### `changeShareable(address[] _owners, uint _required) onlyManyOwners(sha3(msg.data))`

Sets a new list of owners and minimum required number of owners for multi-sig transactions.

#### `revoke(bytes32 operation)`

Revokes a previous confirmation of an operation.

#### `emergencyStop()`

Performs an emergency stop.  In an emergency stop, many functions, including
staking and transferring, are disabled.

#### `release()`

Ends an emergency stop.

#### `disableStopping()`

Permanently disables the ability to perform an emergency stop.
