// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./ILumozOGNFT.sol";

/**
 * @title esMOZ
 * @dev Implementation of the esMOZ
 */
contract esMOZMock is ERC20Upgradeable, ERC20BurnableUpgradeable, AccessControlUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using SafeERC20 for IERC20;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    EnumerableSetUpgradeable.AddressSet private _whitelist;

    address public MOZAddress;
    address public esMOZBurnAddress;
    uint256 public esMOZBurnFoundationBasePoints;

    mapping(address => RedemptionRequest[]) private _redemptionRequests;
    mapping(address => RedemptionRequestExt[]) private _extRedemptionRequests;

    bool private _redemptionActive;

    bool private _pauseConvertToMOZ;
    address OGAddress;
    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[499] private __gap;

    struct RedemptionRequest {
        uint256 amount;
        uint256 startTime;
        uint256 duration;
        bool completed;
    }

    struct RedemptionRequestExt {
        uint256 amount;
        uint256 startTime;
        uint256 duration;
        uint256 endTime;
        bool completed;
        bool cancelled;
        uint256[5] __gap;
    }

    event WhitelistUpdated(address account, bool isAdded);
    event RedemptionStarted(address indexed user, uint256 indexed index, uint256 amount, uint256 duration, uint256 redeemAt);
    event RedemptionCancelled(address indexed user, uint256 indexed index);
    event RedemptionCompleted(address indexed user, uint256 indexed index);
    event MOZTransfer(address indexed _from, address indexed _to, uint256 indexed amount);
    event RedemptionStatusChanged(bool isActive);
    event FoundationBasePointsUpdated(uint256 newBasepoints);
    event ConvertedToEsMOZ(address, uint256);
    event Received(address, uint256);

    function initialize(address _MOZAddress, uint256 _esMOZBurnFoundationBasePoints) public initializer {
        require(_esMOZBurnFoundationBasePoints <= 1000, "Invalid initialize");

        __ERC20_init("esMOZ", "esMOZ");
        __ERC20Burnable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
        
        MOZAddress = _MOZAddress;
        _redemptionActive = false;
        _pauseConvertToMOZ = false;
        esMOZBurnFoundationBasePoints = _esMOZBurnFoundationBasePoints;
    }

    /**
     * @dev Function to change the redemption status
     * @param isActive The new redemption status.
     */
    function changeRedemptionStatus(bool isActive) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _redemptionActive = isActive;
        emit RedemptionStatusChanged(isActive);
    }

    function changeConvertToMOZStatus(bool isActive) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pauseConvertToMOZ = isActive;
    }

    /**
     * @dev Function to mint esMOZ tokens
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev Function to add an address to the whitelist
     * @param account The address to add to the whitelist.
     */
    function addToWhitelist(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _whitelist.add(account);
        emit WhitelistUpdated(account, true);
    }

    /**
     * @dev Function to remove an address from the whitelist
     * @param account The address to remove from the whitelist.
     */
    function removeFromWhitelist(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _whitelist.remove(account);
        emit WhitelistUpdated(account, false);
    }

    /**
     * @dev Function to check if an address is in the whitelist
     * @param account The address to check.
     * @return A boolean indicating if the address is in the whitelist.
     */
    function isWhitelisted(address account) public view returns (bool) {
        return _whitelist.contains(account);
    }

    /**
     * @dev Function to get the whitelisted address at a given index.
     * @param index The index of the address to query.
     * @return The address of the whitelisted account.
     */
    function getWhitelistedAddressAtIndex(uint256 index) public view returns (address) {
        require(index < getWhitelistCount(), "Index out of bounds");
        return _whitelist.at(index);
    }

    /**
     * @dev Function to get the count of whitelisted addresses.
     * @return The count of whitelisted addresses.
     */
    function getWhitelistCount() public view returns (uint256) {
        return _whitelist.length();
    }

    /**
     * @dev Override the transfer function to only allow addresses that are in the white list in the to or from field to go through
     * @param to The address to transfer to.
     * @param amount The amount to transfer.
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(_whitelist.contains(msg.sender) || _whitelist.contains(to), "Transfer not allowed: address not in whitelist");
        return super.transfer(to, amount);
    }

    /**
     * @dev Override the transferFrom function to only allow addresses that are in the white list in the to or from field to go through
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param amount The amount to transfer.
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(_whitelist.contains(from) || _whitelist.contains(to), "Transfer not allowed: address not in whitelist");
        return super.transferFrom(from, to, amount);
    }


    function setOGAddress(address _OGAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        OGAddress = _OGAddress;
    }

    function convertToMOZ(uint256[] memory _tokenIDs) public {
        require(_pauseConvertToMOZ, "Convert is currently inactive");
        uint256 len = _tokenIDs.length;
        IOGNFT OG = IOGNFT(OGAddress);
        require(len <= 20, "CL");
        require(len <= OG.balanceOf(msg.sender), "CB");
        for (uint i = 0 ; i < len; i++) {
            uint256 balance = balanceOf(msg.sender);
            require( balance > 0, "Insufficient esMOZ balance");
            uint256 tokenID = _tokenIDs[i];
            require(OG.ownerOf(tokenID) == msg.sender, "CO");
            uint256 amount = OG.getAmount(tokenID);
            require(amount > 0, "CA");
            if (balance < amount) {
                amount = balance;
            }

            OG.burn(tokenID);
            _burn(msg.sender, amount);

            // redeem the MOZ
            IERC20(MOZAddress).safeTransfer(msg.sender, amount);
        }
    }
}