# Numeraire Ethereum Smart Contract

Authors: Alex Mingoia (@alexmingoia) and Joey Krug (@joeykrug)

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
