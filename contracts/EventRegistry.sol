// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./MizuPassIdentity.sol";
import "./EventContract.sol";
import "./interfaces/IEventContract.sol";
import "./interfaces/IUniswap.sol";

contract EventRegistry {
    MizuPassIdentity public immutable identityContract;
    address public paymentGateway;
    address public platformWallet;
    
    mapping(uint256 => address) public eventContracts;
    mapping(address => uint256[]) public organizerEvents;

    uint256 public eventCounter;
    uint8 public constant MJPY_DECIMALS = 4;
    uint256 public constant EVENT_CREATION_FEE_MJPY = 1;
    address public constant MJPY = 0x115e91ef61ae86FbECa4b5637FD79C806c331632;
    address public owner;
    
    event EventCreated(
        uint256 indexed eventId,
        address indexed organizer,
        address indexed eventContract,
        string ipfsHash
    );
    
    event EventCreationFeeUpdated(uint256 newFee);
    event PaymentGatewayUpdated(address indexed newGateway);
    event PlatformWalletUpdated(address indexed newPlatformWallet);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyEventCreators() {
        require(identityContract.isEventCreator(msg.sender), "Not an event creator");
        _;
    }
    
    constructor(address _identityContract) {
        identityContract = MizuPassIdentity(_identityContract);
        owner = msg.sender;
    }
    
    function createEvent(
        string memory ipfsHash,
        string memory ticketIpfsHash,
        uint256 ticketPrice,
        uint256 maxTickets,
        uint256 eventDate,
        string memory eventName,
        string memory eventSymbol
    ) external onlyEventCreators returns (address eventContract) {
        require(IERC20(MJPY).balanceOf(msg.sender) >= EVENT_CREATION_FEE_MJPY, "Insufficient MJPY balance for event creation fee");
        require(IERC20(MJPY).allowance(msg.sender, address(this)) >= EVENT_CREATION_FEE_MJPY, "Insufficient MJPY allowance for event creation fee");
        require(IERC20(MJPY).transferFrom(msg.sender, address(this), EVENT_CREATION_FEE_MJPY), "Failed to transfer MJPY event creation fee");
        
        require(bytes(ipfsHash).length > 0, "Invalid IPFS hash");
        require(bytes(ticketIpfsHash).length > 0, "Invalid ticket IPFS hash");
        require(ticketPrice > 0, "Invalid ticket price");
        require(maxTickets > 0, "Invalid max tickets");
        require(eventDate > block.timestamp, "Invalid event date");
        require(bytes(eventName).length > 0, "Invalid event name");
        require(bytes(eventName).length <= 50, "Event name too long");
        require(bytes(eventSymbol).length > 0, "Invalid event symbol");
        require(bytes(eventSymbol).length <= 10, "Event symbol too long");
        require(paymentGateway != address(0), "Payment gateway not set");
        require(platformWallet != address(0), "Platform wallet not set");
        
        eventContract = address(new EventContract(
            address(identityContract),
            paymentGateway,
            msg.sender,
            ipfsHash,
            ticketIpfsHash,
            ticketPrice,
            maxTickets,
            eventDate,
            platformWallet,
            eventName,
            eventSymbol
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
        
        IERC20(MJPY).transfer(platformWallet, EVENT_CREATION_FEE_MJPY);
    }
    
    function getEventContract(uint256 eventId) external view returns (address) {
        require(eventId < eventCounter, "Event does not exist");
        return eventContracts[eventId];
    }
    
    function getTotalEvents() external view returns (uint256) {
        return eventCounter;
    }
    
    function getOrganizerEvents(address organizer) external view returns (uint256[] memory) {
        require(organizer != address(0), "Invalid organizer address");
        return organizerEvents[organizer];
    }
    
    function setPaymentGateway(address _paymentGateway) external onlyOwner {
        require(_paymentGateway != address(0), "Invalid gateway address");
        paymentGateway = _paymentGateway;
        emit PaymentGatewayUpdated(_paymentGateway);
    }
    
    function setPlatformWallet(address _platformWallet) external onlyOwner {
        require(_platformWallet != address(0), "Invalid platform wallet address");
        platformWallet = _platformWallet;
        emit PlatformWalletUpdated(_platformWallet);
    }
    
    function withdrawFees() external onlyOwner {
        uint256 balance = IERC20(MJPY).balanceOf(address(this));
        if (balance > 0) {
            IERC20(MJPY).transfer(owner, balance);
        }
    }
    
    function _getActiveEvents(uint256[] memory eventIds) internal view returns (uint256[] memory activeEventIds, address[] memory activeEventContracts) {
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < eventIds.length; i++) {
            uint256 eventId = eventIds[i];
            if (eventContracts[eventId] != address(0)) {
                address eventContract = eventContracts[eventId];
                IEventContract eventContractInterface = IEventContract(eventContract);
                IEventContract.EventData memory eventData = eventContractInterface.getEventData();
                if (eventData.isActive && block.timestamp < eventData.eventDate) {
                    activeCount++;
                }
            }
        }
        
        activeEventIds = new uint256[](activeCount);
        activeEventContracts = new address[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < eventIds.length; i++) {
            uint256 eventId = eventIds[i];
            if (eventContracts[eventId] != address(0)) {
                address eventContract = eventContracts[eventId];
                IEventContract eventContractInterface = IEventContract(eventContract);
                IEventContract.EventData memory eventData = eventContractInterface.getEventData();
                if (eventData.isActive && block.timestamp < eventData.eventDate) {
                    activeEventIds[index] = eventId;
                    activeEventContracts[index] = eventContract;
                    index++;
                }
            }
        }
    }
    
    function getAllActiveEvents() external view returns (
        uint256[] memory eventIds, 
        address[] memory eventContractAddresses,
        IEventContract.EventData[] memory eventDataArray
    ) {
        uint256[] memory allEventIds = new uint256[](eventCounter);
        for (uint256 i = 0; i < eventCounter; i++) {
            allEventIds[i] = i;
        }
        
        (eventIds, eventContractAddresses) = _getActiveEvents(allEventIds);
        
        eventDataArray = new IEventContract.EventData[](eventIds.length);
        for (uint256 i = 0; i < eventIds.length; i++) {
            IEventContract eventContract = IEventContract(eventContractAddresses[i]);
            eventDataArray[i] = eventContract.getEventData();
        }
    }
    
    function getOrganizerActiveEvents(address organizer) external view returns (
        uint256[] memory eventIds, 
        address[] memory eventContractAddresses,
        IEventContract.EventData[] memory eventDataArray
    ) {
        (eventIds, eventContractAddresses) = _getActiveEvents(organizerEvents[organizer]);
        
        eventDataArray = new IEventContract.EventData[](eventIds.length);
        for (uint256 i = 0; i < eventIds.length; i++) {
            IEventContract eventContract = IEventContract(eventContractAddresses[i]);
            eventDataArray[i] = eventContract.getEventData();
        }
    }
    
    function getEventDetails(uint256 eventId) external view returns (IEventContract.EventData memory eventData, address eventContract) {
        require(eventId < eventCounter, "Event does not exist");
        require(eventContracts[eventId] != address(0), "Event contract not found");
        
        eventContract = eventContracts[eventId];
        IEventContract eventContractInterface = IEventContract(eventContract);
        eventData = eventContractInterface.getEventData();
    }
}