// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IMizuhikiSBT.sol";

contract MizuPassIdentity {
    address public constant MIZUHIKI_SBT_CONTRACT = 0x606F72657e72cd1218444C69eF9D366c62C54978;
    
    IMizuhikiSBT private immutable mizuhikiSBT;
    
    mapping(address => bool) public dexWhitelist;
    mapping(address => bytes32) public zkPassportHashes;
    
    address public owner;
    
    event DexWhitelistUpdated(address indexed dexRouter, bool whitelisted);
    event NotVerified(address indexed account, string reason);
    event ZKPassportVerified(address indexed user, bytes32 nullifierHash);
    
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
               zkPassportHashes[account] != bytes32(0) || 
               dexWhitelist[account];
    }
    
    function isVerifiedUser(address account) external view returns (bool) {
        return _isVerifiedUser(account);
    }
    
    function updateDexWhitelist(address _dexRouter, bool _whitelisted) external onlyOwner {
        dexWhitelist[_dexRouter] = _whitelisted;
        emit DexWhitelistUpdated(_dexRouter, _whitelisted);
    }
    
    function verifyMizuhikiSBT(address user) external view returns (bool) {
        return mizuhikiSBT.balanceOf(user) > 0;
    }
    
    function verifyZKPassport(
        address user,
        bytes32 nullifierHash,
        uint[8] calldata proof
    ) external returns (bool) {
        // TODO: Replace with actual ZK proof verification when circom contract is ready
        // For now, we'll implement a placeholder that your friend can replace
        require(verifyZKProof(proof, nullifierHash), "Invalid ZK proof");
        require(zkPassportHashes[user] == bytes32(0), "ZK passport already verified");
        
        zkPassportHashes[user] = nullifierHash;
        emit ZKPassportVerified(user, nullifierHash);
        return true;
    }
    
    function verifyZKProof(uint[8] calldata proof, bytes32 nullifierHash) internal pure returns (bool) {
        // PLACEHOLDER: Replace this with your friend's circom-generated verification contract
        // This should call the actual ZK proof verifier contract
        // For now, we'll return true for testing purposes
        return true;
    }
    
    function isZKPassportVerified(address user) external view returns (bool) {
        return zkPassportHashes[user] != bytes32(0);
    }
}
