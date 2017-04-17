# Numeraire Ethereum Smart Contract

Numeraire is an [ERC20](https://github.com/ethereum/EIPs/issues/20) token used for staking in [Numerai](https://numer.ai)'s machine learning tournament to solve the stock market.  The token mechanics are described in the [whitepaper](https://numer.ai/whitepaper.pdf).

Authors: Alex Mingoia (@alexmingoia), Joey Krug (@joeykrug), and Xander Dunn (@xanderdunn)

## Overview
- Should require multi-sig for some functions
- Should be able to single-sig pause the contract and multi-sig unpause the contract
- All state-changing functions should be disable in the paused state unless it requires multi-sig
- Only Numerai can make stakes, release stakes, destroy stakes, and mint
- Numerai's store of NMR is a "cold wallet": Transfers from it can occur only with multi-sig
- All NMR initially minted is sent to Numerai
- The contract should be upgradable so that the maps of balances, allowances, and stakes remain unchanged but the functions called for staking, releasing stakes, minting, and destroying stakes are changed.
- It should be possible to disable upgradability forever

## Development

### Install
- Clone this repository: `git clone git@github.com:numerai/contract.git && cd contract`
- Install node dependencies: `npm install`

### Lint
- `brew install -g solium` to install solium, the Solidity linter
- `solium --file contracts/FILE`

### Compile
- `brew tap ethereum/ethereum`
- `brew install solidity` to install solc, the Solidity compiler
- `solc --file contracts/FILE`
- `solc --gas contracts/FILE` to estimate gas usage

### Test
- Start the test server: `npm run test-server`
- Run tests: `npm test`
