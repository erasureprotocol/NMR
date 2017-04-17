# Numeraire Ethereum Smart Contract

Numerai is an [ERC20](https://github.com/ethereum/EIPs/issues/20) token used for staking in [Numerai](https://numer.ai)'s machine learning tournament to solve the stock market.  The token mechanics are described in the [whitepaper](https://numer.ai/whitepaper.pdf).

Authors: Alex Mingoia (@alexmingoia), Joey Krug (@joeykrug), and Xander Dunn (@xanderdunn)

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
