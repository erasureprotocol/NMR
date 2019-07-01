pragma solidity >=0.4.25 <0.5.0;

import "./helpers/openzeppelin-solidity/math/SafeMath.sol";
import "./StoppableShareable.sol";
import "./NumeraireShared.sol";


/// @title NumeraireDelegateV3
/// @notice Delegate contract version 3 with the following functionality:
///   1) Disabled upgradability
///   2) Repurposed burn functions
///   3) User NMR balance management through the relay contract
/// @dev Deployed at address
/// @dev Set in tx
/// @dev Retired in tx
contract NumeraireDelegateV3 is StoppableShareable, NumeraireShared {

    address public delegateContract;
    bool public contractUpgradable;
    address[] public previousDelegates;

    string public standard;

    string public name;
    string public symbol;
    uint256 public decimals;

    // set the address of the relay as a constant (stored in runtime code)
    address private constant _RELAY = address(
        0xB17dF4a656505570aD994D023F632D48De04eDF2
    );

    event DelegateChanged(address oldAddress, address newAddress);

    using SafeMath for uint256;

    /* TODO: Can this contructor be removed completely? */
    /// @dev Constructor called on deployment to initialize the delegate contract multisig
    /// @param _owners Array of owner address to control multisig
    /// @param _num_required Uint number of owners required for multisig transaction
    constructor(address[] _owners, uint256 _num_required) public StoppableShareable(_owners, _num_required) {
        require(
            address(this) == address(0x29F709e42C95C604BA76E73316d325077f8eB7b2),
            "incorrect deployment address - check submitting account & nonce."
        );
    }

    //////////////////////////////
    // Special Access Functions //
    //////////////////////////////

    /// @notice Manage Numerai Tournament user balances
    /// @dev Can only be called by numerai through the relay contract
    /// @param _from User address from which to withdraw NMR
    /// @param _to Address where to deposit NMR
    /// @param _value Uint amount of NMR in wei to transfer
    /// @return ok True if the transfer succeeds
    function withdraw(address _from, address _to, uint256 _value) public returns(bool ok) {
        require(msg.sender == _RELAY);
        require(_to != address(0));

        balanceOf[_from] = balanceOf[_from].sub(_value);
        balanceOf[_to] = balanceOf[_to].add(_value);

        emit Transfer(_from, _to, _value);
        return true;
    }

    /// @notice Repurposed function to allow the relay contract to disable token upgradability.
    /// @dev Can only be called by numerai through the relay contract
    /// @return ok True if the call is successful
    function createRound(uint256, uint256, uint256, uint256) public returns (bool ok) {
        require(msg.sender == _RELAY);
        require(contractUpgradable);
        contractUpgradable = false;

        return true;
    }

    /// @notice Repurposed function to allow the relay contract to upgrade the token.
    /// @dev Can only be called by numerai through the relay contract
    /// @param _newDelegate Address of the new delegate contract
    /// @return ok True if the call is successful
    function createTournament(uint256 _newDelegate) public returns (bool ok) {
        require(msg.sender == _RELAY);
        require(contractUpgradable);

        address newDelegate = address(_newDelegate);

        previousDelegates.push(delegateContract);
        emit DelegateChanged(delegateContract, newDelegate);
        delegateContract = newDelegate;

        return true;
    }

    //////////////////////////
    // Repurposed Functions //
    //////////////////////////

    /// @notice Repurposed function to implement token burn from the calling account
    /// @param _value Uint amount of NMR in wei to burn
    /// @return ok True if the burn succeeds
    function mint(uint256 _value) public returns (bool ok) {
        _burn(msg.sender, _value);
        return true;
    }

    /// @notice Repurposed function to implement token burn on behalf of an approved account
    /// @param _to Address from which to burn tokens
    /// @param _value Uint amount of NMR in wei to burn
    /// @return ok True if the burn succeeds
    function numeraiTransfer(address _to, uint256 _value) public returns (bool ok) {
        _burnFrom(_to, _value);
        return true;
    }

    ////////////////////////
    // Internal Functions //
    ////////////////////////

    /// @dev Internal function that burns an amount of the token of a given account.
    /// @param _account The account whose tokens will be burnt.
    /// @param _value The amount that will be burnt.
    function _burn(address _account, uint256 _value) internal {
        require(_account != address(0));

        totalSupply = totalSupply.sub(_value);
        balanceOf[_account] = balanceOf[_account].sub(_value);
        emit Transfer(_account, address(0), _value);
    }

    /// @dev Internal function that burns an amount of the token of a given
    /// account, deducting from the sender's allowance for said account. Uses the
    /// internal burn function.
    /// Emits an Approval event (reflecting the reduced allowance).
    /// @param _account The account whose tokens will be burnt.
    /// @param _value The amount that will be burnt.
    function _burnFrom(address _account, uint256 _value) internal {
        allowance[_account][msg.sender] = allowance[_account][msg.sender].sub(_value);
        _burn(_account, _value);
        emit Approval(_account, msg.sender, allowance[_account][msg.sender]);
    }

    ///////////////////////
    // Trashed Functions //
    ///////////////////////

    /// @dev Disabled function no longer used
    function releaseStake(address, bytes32, uint256, uint256, uint256, bool) public pure returns (bool) {
        revert();
    }

    /// @dev Disabled function no longer used
    function destroyStake(address, bytes32, uint256, uint256) public pure returns (bool) {
        revert();
    }

    /// @dev Disabled function no longer used
    function stake(uint256, bytes32, uint256, uint256, uint256) public pure returns (bool) {
        revert();
    }

    /// @dev Disabled function no longer used
    function stakeOnBehalf(address, uint256, bytes32, uint256, uint256, uint256) public pure returns (bool) {
        revert();
    }
}
