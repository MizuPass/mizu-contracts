// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./MizuPassIdentity.sol";
import "./StealthAddressManager.sol";

contract MizuPassPaymentGateway {
    MizuPassIdentity public immutable identityContract;
    StealthAddressManager public immutable stealthManager;
    
    mapping(bytes32 => bool) public processedPayments;
    
    event PaymentProcessed(
        address indexed payer,
        address indexed recipient,
        uint256 amount,
        bytes32 paymentHash
    );
    
    event TicketPurchased(
        uint256 indexed ticketId,
        address indexed buyer,
        address stealthAddress,
        uint256 amount
    );
    
    modifier onlyVerifiedUsers() {
        require(identityContract.isVerifiedUser(msg.sender), "User not verified");
        _;
    }
    
    constructor(address _identityContract, address _stealthManager) {
        identityContract = MizuPassIdentity(_identityContract);
        stealthManager = StealthAddressManager(_stealthManager);
    }
    
    function purchaseTicketWithJETH(
        uint256 ticketId,
        address stealthAddress,
        uint256 mjpyRequired,
        uint256 deadline
    ) external payable onlyVerifiedUsers {
        require(stealthAddress != address(0), "Invalid stealth address");
        require(mjpyRequired > 0, "Invalid amount");
        require(deadline > block.timestamp, "Deadline passed");
        
        require(msg.value >= mjpyRequired, "Insufficient payment");
        
        bytes32 paymentHash = keccak256(abi.encode(
            msg.sender,
            stealthAddress,
            mjpyRequired,
            block.timestamp
        ));
        
        require(!processedPayments[paymentHash], "Payment already processed");
        processedPayments[paymentHash] = true;
        
        (bool success, ) = msg.sender.call{value: mjpyRequired}("");
        require(success, "Transfer to organizer failed");
        
        emit PaymentProcessed(
            msg.sender,
            msg.sender,
            mjpyRequired,
            paymentHash
        );
        
        emit TicketPurchased(ticketId, msg.sender, stealthAddress, mjpyRequired);
        
        if (msg.value > mjpyRequired) {
            payable(msg.sender).transfer(msg.value - mjpyRequired);
        }
    }
    
    function getPaymentStatus(bytes32 paymentHash) external view returns (bool) {
        return processedPayments[paymentHash];
    }
    
    function quoteJETHForMJPY(uint256 mjpyAmount) external pure returns (uint256 jethNeeded) {
        return mjpyAmount;
    }
}
