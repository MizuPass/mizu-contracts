// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./MizuPassIdentity.sol";
import "./MizuPassPaymentGateway.sol";
import "./interfaces/IEventContract.sol";

contract EventContract is ERC721, Ownable, ReentrancyGuard, IEventContract {
    MizuPassIdentity public immutable identityContract;
    MizuPassPaymentGateway public immutable paymentGateway;
    
    address public immutable platformWallet;
    uint256 public constant PLATFORM_FEE_BPS = 250; // 2.5%
    
    EventData public eventData;
    uint256 private _tokenIdCounter;
    
    mapping(uint256 => bool) public hasAttended;
    mapping(uint256 => uint256) public originalPurchasePrice;
    
    event EventMetadataUpdated(string newIpfsHash);
    event EventDateUpdated(uint256 newEventDate);
    event MaxTicketsUpdated(uint256 newMaxTickets);
    event PlatformFeeCollected(uint256 amount, address platformWallet);
    
    modifier onlyRegularUsers() {
        require(identityContract.isRegularUser(msg.sender), "Not a regular user");
        _;
    }
    
    modifier onlyOrganizer() {
        require(msg.sender == eventData.organizer, "Not organizer");
        _;
    }
    
    modifier onlyTicketOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Not ticket owner");
        _;
    }
    
    constructor(
        address _identityContract,
        address _paymentGateway,
        address _organizer,
        string memory _ipfsHash,
        uint256 _ticketPrice,
        uint256 _maxTickets,
        uint256 _eventDate,
        address _platformWallet
    ) ERC721("MizuPass Ticket", "MPT") Ownable(_organizer) {
        require(_identityContract != address(0), "Invalid identity contract");
        require(_paymentGateway != address(0), "Invalid payment gateway");
        require(_organizer != address(0), "Invalid organizer");
        require(bytes(_ipfsHash).length > 0, "Invalid IPFS hash");
        require(_platformWallet != address(0), "Invalid platform wallet");
        
        identityContract = MizuPassIdentity(_identityContract);
        paymentGateway = MizuPassPaymentGateway(_paymentGateway);
        platformWallet = _platformWallet;
        
        eventData = EventData({
            organizer: _organizer,
            ipfsHash: _ipfsHash,
            ticketPrice: _ticketPrice,
            maxTickets: _maxTickets,
            ticketsSold: 0,
            isActive: true,
            eventDate: _eventDate
        });
        
        emit EventCreated(
            _organizer,
            _ipfsHash,
            _ticketPrice,
            _maxTickets,
            _eventDate
        );
    }
    
    function purchaseTicket(address stealthAddress) external payable override onlyRegularUsers nonReentrant {
        require(eventData.isActive, "Event not active");
        require(eventData.ticketsSold < eventData.maxTickets, "Sold out");
        require(block.timestamp < eventData.eventDate, "Event has passed");
        require(stealthAddress != address(0), "Invalid stealth address");
        
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(stealthAddress, tokenId);
        
        originalPurchasePrice[tokenId] = eventData.ticketPrice;
        eventData.ticketsSold++;
        

        uint256 platformFee = (eventData.ticketPrice * PLATFORM_FEE_BPS) / 10000;
        uint256 organizerAmount = eventData.ticketPrice - platformFee;
        
        paymentGateway.purchaseTicketWithJETH{value: organizerAmount}(
            tokenId,
            stealthAddress,
            organizerAmount,
            block.timestamp + 300
        );
        
        if (platformFee > 0) {
            payable(platformWallet).transfer(platformFee);
            emit PlatformFeeCollected(platformFee, platformWallet);
        }
        

        if (msg.value > eventData.ticketPrice) {
            payable(msg.sender).transfer(msg.value - eventData.ticketPrice);
        }
        
        emit TicketPurchased(stealthAddress, tokenId, eventData.ticketPrice);
    }
    
    function resaleTicket(
        uint256 tokenId,
        uint256 price,
        address buyer
    ) external payable override onlyTicketOwner(tokenId) onlyRegularUsers nonReentrant {
        require(eventData.isActive, "Event not active");
        require(price <= eventData.ticketPrice, "Resale price cannot exceed original ticket price");
        require(block.timestamp < eventData.eventDate, "Event has passed");
        require(!hasAttended[tokenId], "Ticket already used");
        require(buyer != address(0), "Invalid buyer address");
        require(buyer != ownerOf(tokenId), "Cannot sell to self");
        
        uint256 platformFee = (price * PLATFORM_FEE_BPS) / 10000;
        uint256 sellerAmount = price - platformFee;
        

        _transfer(ownerOf(tokenId), buyer, tokenId);
        
        
        if (platformFee > 0) {
            payable(platformWallet).transfer(platformFee);
            emit PlatformFeeCollected(platformFee, platformWallet);
        }
        
        payable(msg.sender).transfer(sellerAmount);
        
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
        
        emit TicketResold(tokenId, msg.sender, buyer, price);
    }
    
    function setEventActive(bool _isActive) external override onlyOrganizer {
        eventData.isActive = _isActive;
    }
    
    function markAttendance(uint256 tokenId) external onlyOrganizer {
        require(!hasAttended[tokenId], "Ticket already used");
        hasAttended[tokenId] = true;
    }
    
    function updateEventMetadata(string memory newIpfsHash) external onlyOrganizer {
        require(bytes(newIpfsHash).length > 0, "Invalid IPFS hash");
        eventData.ipfsHash = newIpfsHash;
        emit EventMetadataUpdated(newIpfsHash);
    }
    
    function updateEventDate(uint256 newEventDate) external onlyOrganizer {
        require(newEventDate > block.timestamp, "Event date must be in future");
        require(eventData.ticketsSold == 0, "Cannot change date after tickets sold");
        eventData.eventDate = newEventDate;
        emit EventDateUpdated(newEventDate);
    }
    
    function updateMaxTickets(uint256 newMaxTickets) external onlyOrganizer {
        require(newMaxTickets > 0, "Invalid max tickets");
        require(newMaxTickets >= eventData.ticketsSold, "Cannot reduce below sold tickets");
        eventData.maxTickets = newMaxTickets;
        emit MaxTicketsUpdated(newMaxTickets);
    }
    
    function getEventData() external view override returns (EventData memory) {
        return eventData;
    }
    
    function getTicketData(uint256 tokenId) external view returns (
        address owner,
        bool attended,
        uint256 originalPrice
    ) {
        return (
            ownerOf(tokenId),
            hasAttended[tokenId],
            originalPurchasePrice[tokenId]
        );
    }  
}