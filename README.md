# NMR Ethereum Smart Contract

Numeraire (NMR) is an [ERC-20](https://eips.ethereum.org/EIPS/eip-20) token used for staking and burning.

NMR is the native token of the [Erasure Protocol](https://erasure.world/).

See [documentation](https://docs.erasure.world/) for more information.

Security Contact: security@numer.ai

## Validated Metrics

[NMR circulating supply](https://numer.ai/nmr/circulating_supply)  
[Etherscan token tracker](https://etherscan.io/token/0x1776e1f26f98b1a5df9cd347953a26dd3cb46671)  
[Coingecko token tracker](https://www.coingecko.com/en/coins/numeraire)  
[DeFiPulse token tracker](https://defipulse.com/erasure)

## Deployed Contracts

| Contract            | Address                                                                                                               |
| ------------------- | --------------------------------------------------------------------------------------------------------------------- |
| NumeraireBackend    | [0x1776e1f26f98b1a5df9cd347953a26dd3cb46671](https://etherscan.io/address/0x1776e1f26f98b1a5df9cd347953a26dd3cb46671) |
| NumeraireDelegateV1 | [0xF32e4724946d4e288B3042d504919CE68C4Fda9c](https://etherscan.io/address/0xF32e4724946d4e288B3042d504919CE68C4Fda9c) |
| NumeraireDelegateV2 | [0x3548718A49EE7cd348e50290D446D9F1A1f9C59E](https://etherscan.io/address/0x3548718A49EE7cd348e50290D446D9F1A1f9C59E) |
| NumeraireDelegateV3 | [0x29F709e42C95C604BA76E73316d325077f8eB7b2](https://etherscan.io/address/0x29F709e42C95C604BA76E73316d325077f8eB7b2) |
| UpgradeDelegate     | [0x3361F79f0819fD5feaA37bea44C8a33d98b2A1cd](https://etherscan.io/address/0x3361F79f0819fD5feaA37bea44C8a33d98b2A1cd) |
| Relay               | [0xB17dF4a656505570aD994D023F632D48De04eDF2](https://etherscan.io/address/0xB17dF4a656505570aD994D023F632D48De04eDF2) |

## Security Audits

| Audit                                           | Provider                                      | Date       |
| ----------------------------------------------- | --------------------------------------------- | ---------- |
| [NMR Token](./audits/security_audit.pdf)        | [New Alchemy](https://newalchemy.io/)         | May 2017   |
| [NMR Code Fix](./audits/2018_upgrade_audit.pdf) | [New Alchemy](https://newalchemy.io/)         | April 2018 |
| [NMR 2.0](./audits/NMR2_audit.pdf)              | [Trail of Bits](https://www.trailofbits.com/) | July 2019  |

## Whitepapers

| Project                                                                               | Authors                                                 | Date          |
| ------------------------------------------------------------------------------------- | ------------------------------------------------------- | ------------- |
| [Numerai](./whitepapers/numerai-whitepaper-2017.pdf)                                  | Richard Craib, Geoffrey Bradway, Xander Dunn, Joey Krug | February 2017 |
| [Erasure Quant](https://docs.erasure.world/erasure-quant-docs/erasure-quant-overview) | Richard Craib, James Geary, Jason Paryani               | August 2019   |
| [Erasure Bay](https://docs.erasure.world/erasurebay-docs/bay-overview)                | Stephane Gosselin, Jonathan Sidego                      | March 2020    |

## Specification

### ERC-20

```
function approve(address _spender, uint256 _value);
function transfer(address _to, uint256 _value);
function transferFrom(address _from, address _to, uint256 _value);

function totalSupply();
function balanceOf(address _owner);
function allowance(address _owner, address _spender);

event Transfer(address indexed _from, address indexed _to, uint256 _value);
event Approval(address indexed _owner, address indexed _spender, uint256 _value);
```

Refer to [ERC-20 standard](https://eips.ethereum.org/EIPS/eip-20) for detailed specification.

_Note:_ NMR deviates from ERC-20 in the implementation of the `approve()` function to prevent the [ERC-20 approve race condition](https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM).

The `approve()` function is limited to changing the allowance from zero or to zero.

In order to change the allowance from a non-zero value to a different non-zero value in a single transaction. The user must use the `changeApproval()` function.

```
function changeApproval(address _spender, uint256 _oldValue, uint256 _newValue);
```

Sets the approval to a new value while checking that the previous approval
value is what we expected.

- `_spender` is the address of the contract.
- `_oldValue` is the current amount the contract is allowed to spend.
- `_newValue` is the new amount to allow the contract to spend.

### Burning

The `mint()` and `numeraiTransfer()` functions have been repurposed from their initial use in order to support native token burns as implemented in OpenZeppelin's [ERC20Burnable](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20Burnable.sol).

_Note: The caller must check the return values of these functions as they return false on failure._

```
/**
 * @dev Destoys `amount` tokens from `msg.sender`, reducing the total supply.
 *
 * Emits a `Transfer` event with `to` set to the zero address.
 *
 * Requirements:
 * - `account` must have at least `amount` tokens.
 */
function mint(uint256 _value);
   => function burn(uint256 amount);

/**
 * @dev Destoys `amount` tokens from `account`.`amount` is then deducted
 * from the caller's allowance.
 *
 * Emits an `Approval` event indicating the updated allowance.
 * Emits a `Transfer` event with `to` set to the zero address.
 *
 * Requirements:
 * - `account` must have at least `amount` tokens.
 * - `account` must have approved `msg.sender` with allowance of at least `amount` tokens.
 */
function numeraiTransfer(address _to, uint256 _value);
   => function burnFrom(address account, uint256 amount);
```

### Custody for Numerai Tournament

Numerai performs custody of the token for participants in the [Numerai Tournament](https://numer.ai). This removes participation barriers as users no longer need to pay for gas or manage their own private keys. The `withdraw()` function can be used by Numerai to transfer tokens from the first 1 million accounts (0x00...00000000 to 0x00...000F4240).

```
function withdraw(address _from, address _to, uint256 _value);
```

## Deprecated Features

All other contract methods belong to the following features which have been disabled as a part of the NMR 2.0 upgrade.

- Multisignature
- Emergency Stops
- Minting
- Upgradeability
