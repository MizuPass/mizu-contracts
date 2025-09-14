// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IMizuhikiSBT.sol";

contract MizuPassIdentity {
    address public constant MIZUHIKI_SBT_CONTRACT = 0x606F72657e72cd1218444C69eF9D366c62C54978;
    
    IMizuhikiSBT private immutable mizuhikiSBT;
    
    mapping(address => bool) public dexWhitelist;
    mapping(address => bytes32) public zkPassportIdentifiers;
    mapping(bytes32 => bool) public usedIdentifiers;
    
    enum UserRole { None, EventCreator, RegularUser }
    mapping(address => UserRole) public userRoles;
    
    address public owner;
    
    event DexWhitelistUpdated(address indexed dexRouter, bool whitelisted);
    event ZKPassportVerified(address indexed user, bytes32 nullifierHash);
    event UserRoleRegistered(address indexed user, UserRole role);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyVerifiedUsers() {
        require(_isVerifiedUser(msg.sender), "User not verified");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        mizuhikiSBT = IMizuhikiSBT(MIZUHIKI_SBT_CONTRACT);
    }
    
    function _isVerifiedUser(address account) internal view returns (bool) {
        return mizuhikiSBT.balanceOf(account) > 0 ||
               zkPassportIdentifiers[account] != bytes32(0) ||
               dexWhitelist[account];
    }
    
    function isVerifiedUser(address account) external view returns (bool) {
        return _isVerifiedUser(account);
    }
    
    function updateDexWhitelist(address _dexRouter, bool _whitelisted) external onlyOwner {
        require(_dexRouter != address(0), "Invalid DEX router address");
        dexWhitelist[_dexRouter] = _whitelisted;
        emit DexWhitelistUpdated(_dexRouter, _whitelisted);
    }
    
    function verifyMizuhikiSBT(address user) external view returns (bool) {
        require(user != address(0), "Invalid user address");
        return mizuhikiSBT.balanceOf(user) > 0;
    }
    
    function registerZKPassportUser(
        bytes32 uniqueIdentifier
    ) external returns (bool) {
        require(uniqueIdentifier != bytes32(0), "Invalid identifier");
        require(zkPassportIdentifiers[msg.sender] == bytes32(0), "User already registered");
        require(!usedIdentifiers[uniqueIdentifier], "Identifier already used");

        zkPassportIdentifiers[msg.sender] = uniqueIdentifier;
        usedIdentifiers[uniqueIdentifier] = true;

        emit ZKPassportVerified(msg.sender, uniqueIdentifier);
        return true;
    }
    
    function isZKPassportVerified(address user) external view returns (bool) {
        require(user != address(0), "Invalid user address");
        return zkPassportIdentifiers[user] != bytes32(0);
    }

    function getUniqueIdentifier(address user) external view returns (bytes32) {
        require(user != address(0), "Invalid user address");
        return zkPassportIdentifiers[user];
    }
    
    function registerUserRole(UserRole role) external onlyVerifiedUsers {
        require(role == UserRole.EventCreator || role == UserRole.RegularUser, "Invalid role");
        require(userRoles[msg.sender] == UserRole.None, "User already registered");
        
        userRoles[msg.sender] = role;
        
        emit UserRoleRegistered(msg.sender, role);
    }
    
    function getUserRole(address user) external view returns (UserRole) {
        return userRoles[user];
    }
    
    function isEventCreator(address user) external view returns (bool) {
        return userRoles[user] == UserRole.EventCreator;
    }
    
    function isRegularUser(address user) external view returns (bool) {
        return userRoles[user] == UserRole.RegularUser;
    }
    
    function isUserRegistered(address user) external view returns (bool) {
        return userRoles[user] != UserRole.None;
    }
}