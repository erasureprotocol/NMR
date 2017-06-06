# Numeraire Ethereum Smart Contract

Numeraire is an [ERC20](https://github.com/ethereum/EIPs/issues/20) token used for staking in [Numerai](https://numer.ai)'s machine learning tournament to solve the stock market.  The token mechanics are described in the [whitepaper](https://numer.ai/whitepaper.pdf).

Authors: [Alex Mingoia](https://github.com/alexmingoia), [Joey Krug](https://github.com/joeykrug), [Xander Dunn](https://github.com/xanderdunn), and [Philip Monk](https://github.com/philipcmonk)

## Overview
- Should require multi-sig for some functions
- Should be able to single-sig pause the contract and multi-sig unpause the contract
- All state-changing functions should be disabled in the paused state unless it requires multi-sig
- Only Numerai can release stakes, destroy stakes, and mint
- Trainsfers from Numerai's store of NMR require multi-sig
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
