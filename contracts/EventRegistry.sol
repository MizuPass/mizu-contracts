// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./MizuPassIdentity.sol";
import "./interfaces/IEventContract.sol";

contract EventRegistry {
    MizuPassIdentity public immutable identityContract;
    address public paymentGateway;
    
    mapping(uint256 => address) public eventContracts;
    mapping(address => uint256[]) public organizerEvents;
    uint256 public eventCounter;
    uint256 public eventCreationFee = 0.01 ether;
    
    address public owner;
    
    event EventCreated(
        uint256 indexed eventId,
        address indexed organizer,
        address indexed eventContract,
        string ipfsHash
    );
    
    event EventCreationFeeUpdated(uint256 newFee);
    event PaymentGatewayUpdated(address indexed newGateway);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyVerifiedUsers() {
        require(identityContract.isVerifiedUser(msg.sender), "User not verified");
        _;
    }
    
    constructor(address _identityContract) {
        identityContract = MizuPassIdentity(_identityContract);
        owner = msg.sender;
    }
    
    function createEvent(
        string memory ipfsHash,
        uint256 ticketPrice,
        uint256 maxTickets,
        uint256 eventDate,
        uint256 maxResalePrice,
        uint256 royaltyBps
    ) external payable onlyVerifiedUsers returns (address eventContract) {
        require(msg.value >= eventCreationFee, "Insufficient creation fee");
        require(ticketPrice > 0, "Invalid ticket price");
        require(maxTickets > 0, "Invalid max tickets");
        require(eventDate > block.timestamp, "Invalid event date");
        require(royaltyBps <= 1000, "Royalty too high");
        
        eventContract = address(new EventContract(
            address(identityContract),
            msg.sender,
            ipfsHash,
            ticketPrice,
            maxTickets,
            eventDate,
            maxResalePrice,
            royaltyBps
        ));
        
        eventContracts[eventCounter] = eventContract;
        organizerEvents[msg.sender].push(eventCounter);
        
        emit EventCreated(
            eventCounter,
            msg.sender,
            eventContract,
            ipfsHash
        );
        
        eventCounter++;
        
        if (msg.value > eventCreationFee) {
            payable(msg.sender).transfer(msg.value - eventCreationFee);
        }
    }
    
    function getEventContract(uint256 eventId) external view returns (address) {
        return eventContracts[eventId];
    }
    
    function getOrganizerEvents(address organizer) external view returns (uint256[] memory) {
        return organizerEvents[organizer];
    }
    
    function setEventCreationFee(uint256 _fee) external onlyOwner {
        eventCreationFee = _fee;
        emit EventCreationFeeUpdated(_fee);
    }
    
    function setPaymentGateway(address _paymentGateway) external onlyOwner {
        require(_paymentGateway != address(0), "Invalid gateway address");
        paymentGateway = _paymentGateway;
        emit PaymentGatewayUpdated(_paymentGateway);
    }
    
    function withdrawFees() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}

contract EventContract {
    constructor(
        address _identityContract,
        address _organizer,
        string memory _ipfsHash,
        uint256 _ticketPrice,
        uint256 _maxTickets,
        uint256 _eventDate,
        uint256 _maxResalePrice,
        uint256 _royaltyBps
    ) {}
}
