/**
 *Submitted for verification at Etherscan.io on 2019-06-27
*/

pragma solidity >=0.4.25 <0.6.0;

interface INMR {

    /* ERC20 Interface */

    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    /* NMR Special Interface */

    // used for user balance management
    function withdraw(address _from, address _to, uint256 _value) external returns(bool ok);

    // used for migrating active stakes
    function destroyStake(address _staker, bytes32 _tag, uint256 _tournamentID, uint256 _roundID) external returns (bool ok);

    // used for disabling token upgradability
    function createRound(uint256, uint256, uint256, uint256) external returns (bool ok);

    // used for upgrading the token delegate logic
    function createTournament(uint256 _newDelegate) external returns (bool ok);

    // used like burn(uint256)
    function mint(uint256 _value) external returns (bool ok);

    // used like burnFrom(address, uint256)
    function numeraiTransfer(address _to, uint256 _value) external returns (bool ok);

    // used to check if upgrade completed
    function contractUpgradable() external view returns (bool);

    function getTournament(uint256 _tournamentID) external view returns (uint256, uint256[] memory);

    function getRound(uint256 _tournamentID, uint256 _roundID) external view returns (uint256, uint256, uint256);

    function getStake(uint256 _tournamentID, uint256 _roundID, address _staker, bytes32 _tag) external view returns (uint256, uint256, bool, bool);

}



/**
 * @title Initializable
 *
 * @dev Helper contract to support initializer functions. To use it, replace
 * the constructor with a function that has the `initializer` modifier.
 * WARNING: Unlike constructors, initializer functions must be manually
 * invoked. This applies both to deploying an Initializable contract, as well
 * as extending an Initializable contract via inheritance.
 * WARNING: When used with inheritance, manual care must be taken to not invoke
 * a parent initializer twice, or ensure that all initializers are idempotent,
 * because this is not dealt with automatically as with constructors.
 */
contract Initializable {

  /**
   * @dev Indicates that the contract has been initialized.
   */
  bool private initialized;

  /**
   * @dev Indicates that the contract is in the process of being initialized.
   */
  bool private initializing;

  /**
   * @dev Modifier to use in the initializer function of a contract.
   */
  modifier initializer() {
    require(initializing || isConstructor() || !initialized, "Contract instance has already been initialized");

    bool wasInitializing = initializing;
    initializing = true;
    initialized = true;

    _;

    initializing = wasInitializing;
  }

  /// @dev Returns true if and only if the function is running in the constructor
  function isConstructor() private view returns (bool) {
    // extcodesize checks the size of the code stored in an address, and
    // address returns the current address. Since the code is still not
    // deployed when running a constructor, any checks on its code size will
    // yield zero, making it an effective way to detect if a contract is
    // under construction or not.
    uint256 cs;
    assembly { cs := extcodesize(address) }
    return cs == 0;
  }

  // Reserved storage space to allow for layout changes in the future.
  uint256[50] private ______gap;
}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable is Initializable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    function initialize(address sender) public initializer {
        _owner = sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @return the address of the owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * @notice Renouncing to ownership will leave the contract without an owner.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    uint256[50] private ______gap;
}



contract Manageable is Initializable, Ownable {
    address private _manager;

    event ManagementTransferred(address indexed previousManager, address indexed newManager);

    /**
     * @dev The Managable constructor sets the original `manager` of the contract to the sender
     * account.
     */
    function initialize(address sender) initializer public {
        Ownable.initialize(sender);
        _manager = sender;
        emit ManagementTransferred(address(0), _manager);
    }

    /**
     * @return the address of the manager.
     */
    function manager() public view returns (address) {
        return _manager;
    }

    /**
     * @dev Throws if called by any account other than the owner or manager.
     */
    modifier onlyManagerOrOwner() {
        require(isManagerOrOwner());
        _;
    }

    /**
     * @return true if `msg.sender` is the owner or manager of the contract.
     */
    function isManagerOrOwner() public view returns (bool) {
        return (msg.sender == _manager || isOwner());
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newManager.
     * @param newManager The address to transfer management to.
     */
    function transferManagement(address newManager) public onlyOwner {
        require(newManager != address(0));
        emit ManagementTransferred(_manager, newManager);
        _manager = newManager;
    }

    uint256[50] private ______gap;
}



contract Relay is Manageable {

    bool public active = true;
    bool private _upgraded;

    // set NMR token, 1M address, null address, burn address as constants
    address private constant _TOKEN = address(
        0x1776e1F26f98b1A5dF9cD347953a26dd3Cb46671
    );
    address private constant _ONE_MILLION_ADDRESS = address(
        0x00000000000000000000000000000000000F4240
    );
    address private constant _NULL_ADDRESS = address(
        0x0000000000000000000000000000000000000000
    );
    address private constant _BURN_ADDRESS = address(
        0x000000000000000000000000000000000000dEaD
    );

    /// @dev Throws if the address does not match the required conditions.
    modifier isUser(address _user) {
        require(
            _user <= _ONE_MILLION_ADDRESS
            && _user != _NULL_ADDRESS
            && _user != _BURN_ADDRESS
            , "_from must be a user account managed by Numerai"
        );
        _;
    }

    /// @dev Throws if called after the relay is disabled.
    modifier onlyActive() {
        require(active, "User account relay has been disabled");
        _;
    }

    /// @notice Contructor function called at time of deployment
    /// @param _owner The initial owner and manager of the relay
    constructor(address _owner) public {
        require(
            address(this) == address(0xB17dF4a656505570aD994D023F632D48De04eDF2),
            "incorrect deployment address - check submitting account & nonce."
        );

        Manageable.initialize(_owner);
    }

    /// @notice Transfer NMR on behalf of a Numerai user
    ///         Can only be called by Manager or Owner
    /// @dev Can only be used on the first 1 million ethereum addresses
    /// @param _from The user address
    /// @param _to The recipient address
    /// @param _value The amount of NMR in wei
    function withdraw(address _from, address _to, uint256 _value) public onlyManagerOrOwner onlyActive isUser(_from) returns (bool ok) {
        require(INMR(_TOKEN).withdraw(_from, _to, _value));
        return true;
    }

    /// @notice Burn the NMR sent to address 0 and burn address
    function burnZeroAddress() public {
        uint256 amtZero = INMR(_TOKEN).balanceOf(_NULL_ADDRESS);
        uint256 amtBurn = INMR(_TOKEN).balanceOf(_BURN_ADDRESS);
        require(INMR(_TOKEN).withdraw(_NULL_ADDRESS, address(this), amtZero));
        require(INMR(_TOKEN).withdraw(_BURN_ADDRESS, address(this), amtBurn));
        uint256 amtThis = INMR(_TOKEN).balanceOf(address(this));
        _burn(amtThis);
    }

    /// @notice Permanantly disable the relay contract
    ///         Can only be called by Owner
    function disable() public onlyOwner onlyActive {
        active = false;
    }

    /// @notice Permanantly disable token upgradability
    ///         Can only be called by Owner
    function disableTokenUpgradability() public onlyOwner onlyActive {
        require(INMR(_TOKEN).createRound(uint256(0),uint256(0),uint256(0),uint256(0)));
    }

    /// @notice Upgrade the token delegate logic.
    ///         Can only be called by Owner
    /// @param _newDelegate Address of the new delegate contract
    function changeTokenDelegate(address _newDelegate) public onlyOwner onlyActive {
        require(INMR(_TOKEN).createTournament(uint256(_newDelegate)));
    }

    /// @notice Get the address of the NMR token contract
    /// @return The address of the NMR token contract
    function token() external pure returns (address) {
        return _TOKEN;
    }

    /// @notice Internal helper function to burn NMR
    /// @dev If before the token upgrade, sends the tokens to address 0
    ///      If after the token upgrade, calls the repurposed mint function to burn
    /// @param _value The amount of NMR in wei
    function _burn(uint256 _value) internal {
        if (INMR(_TOKEN).contractUpgradable()) {
            require(INMR(_TOKEN).transfer(address(0), _value));
        } else {
            require(INMR(_TOKEN).mint(_value), "burn not successful");
        }
    }
}
