// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./MizuPassIdentity.sol";

contract StealthAddressManager {
    MizuPassIdentity public immutable identityContract;
    
    uint256 private constant CURVE_ORDER = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
    
    event StealthPayment(
        bytes32 indexed stealthHash,
        uint256 amount,
        bytes encryptedPayload
    );
    
    event StealthAddressGenerated(
        address indexed user,
        address stealthAddress,
        bytes32 sharedSecret
    );
    
    modifier onlyVerifiedUsers() {
        require(identityContract.isVerifiedUser(msg.sender), "User not verified");
        _;
    }
    
    constructor(address _identityContract) {
        identityContract = MizuPassIdentity(_identityContract);
    }
    
    function generateStealthAddress(
        bytes32 spendKey,
        bytes32 viewKey,
        uint256 randomness
    ) external pure returns (address stealth, bytes32 sharedSecret) {
        bytes32 sharedPoint = ecmul(viewKey, randomness);
        sharedSecret = keccak256(abi.encode(sharedPoint));
        
        bytes32 stealthPrivKey = bytes32(addmod(
            uint256(spendKey),
            uint256(keccak256(abi.encode(sharedSecret, 0))),
            CURVE_ORDER
        ));
        
        stealth = address(uint160(uint256(keccak256(abi.encode(stealthPrivKey)))));
    }
    
    function generateStealthAddressForUser(
        bytes32 spendKey,
        bytes32 viewKey,
        uint256 randomness
    ) external onlyVerifiedUsers returns (address stealth, bytes32 sharedSecret) {
        (stealth, sharedSecret) = this.generateStealthAddress(spendKey, viewKey, randomness);
        
        emit StealthAddressGenerated(msg.sender, stealth, sharedSecret);
    }
    
    function sendToStealth(
        address stealthAddr,
        uint256 amount,
        bytes calldata encryptedData
    ) external onlyVerifiedUsers {
        require(stealthAddr != address(0), "Invalid stealth address");
        require(amount > 0, "Invalid amount");
        
        (bool success, ) = stealthAddr.call{value: amount}("");
        require(success, "Transfer failed");
        
        bytes32 stealthHash = keccak256(abi.encode(stealthAddr, amount, block.timestamp));
        emit StealthPayment(stealthHash, amount, encryptedData);
    }
    
    function verifyStealthOwnership(
        address stealthAddr,
        bytes32 spendKey,
        bytes32 viewKey,
        uint256 randomness
    ) external view returns (bool) {
        (address generatedStealth, ) = this.generateStealthAddress(spendKey, viewKey, randomness);
        return generatedStealth == stealthAddr;
    }
    
    function ecmul(bytes32 point, uint256 scalar) internal pure returns (bytes32) {
        return keccak256(abi.encode(point, scalar));
    }
}
