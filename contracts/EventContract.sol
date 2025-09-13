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
    
    EventData public eventData;
    uint256 private _tokenIdCounter;
    
    mapping(uint256 => address) public ticketOwners;
    mapping(uint256 => bool) public hasAttended;
    mapping(uint256 => uint256) public originalPurchasePrice;
    
    event QRCodeUpdated(uint256 indexed tokenId, bytes32 newQRHash);
    
    modifier onlyVerifiedUsers() {
        require(identityContract.isVerifiedUser(msg.sender), "User not verified");
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
        uint256 _maxResalePrice,
        uint256 _royaltyBps
    ) ERC721("MizuPass Ticket", "MPT") Ownable(_organizer) {
        identityContract = MizuPassIdentity(_identityContract);
        paymentGateway = MizuPassPaymentGateway(_paymentGateway);
        
        eventData = EventData({
            organizer: _organizer,
            ipfsHash: _ipfsHash,
            ticketPrice: _ticketPrice,
            maxTickets: _maxTickets,
            ticketsSold: 0,
            isActive: true,
            eventDate: _eventDate,
            maxResalePrice: _maxResalePrice,
            royaltyBps: _royaltyBps
        });
        
        emit EventCreated(
            _organizer,
            _ipfsHash,
            _ticketPrice,
            _maxTickets,
            _eventDate
        );
    }
    
    function purchaseTicket(address stealthAddress) external payable override onlyVerifiedUsers nonReentrant {
        require(eventData.isActive, "Event not active");
        require(eventData.ticketsSold < eventData.maxTickets, "Sold out");
        require(block.timestamp < eventData.eventDate, "Event has passed");
        
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(stealthAddress, tokenId);
        
        ticketOwners[tokenId] = stealthAddress;
        originalPurchasePrice[tokenId] = eventData.ticketPrice;
        eventData.ticketsSold++;
        
        paymentGateway.purchaseTicketWithJETH{value: msg.value}(
            tokenId,
            stealthAddress,
            eventData.ticketPrice,
            block.timestamp + 300
        );
        
        emit TicketPurchased(stealthAddress, tokenId, eventData.ticketPrice);
    }
    
    function resaleTicket(
        uint256 tokenId,
        uint256 price,
        address buyer
    ) external payable override onlyTicketOwner(tokenId) onlyVerifiedUsers nonReentrant {
        require(eventData.isActive, "Event not active");
        require(price <= eventData.maxResalePrice, "Price too high");
        require(block.timestamp < eventData.eventDate, "Event has passed");
        require(!hasAttended[tokenId], "Ticket already used");
        
        paymentGateway.purchaseTicketWithJETH{value: msg.value}(
            tokenId,
            buyer,
            price,
            block.timestamp + 300
        );
        
        _transfer(ownerOf(tokenId), buyer, tokenId);
        ticketOwners[tokenId] = buyer;
        
        _updateTicketQR(tokenId);
        
        emit TicketResold(tokenId, msg.sender, buyer, price);
    }
    
    function setEventActive(bool _isActive) external override onlyOrganizer {
        eventData.isActive = _isActive;
    }
    
    function updateResaleControls(uint256 maxPrice, uint256 royaltyBps) external override onlyOrganizer {
        require(royaltyBps <= 1000, "Royalty too high");
        eventData.maxResalePrice = maxPrice;
        eventData.royaltyBps = royaltyBps;
    }
    
    function markAttendance(uint256 tokenId) external onlyOrganizer {
        require(ownerOf(tokenId) != address(0), "Invalid token");
        hasAttended[tokenId] = true;
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
    
    function _updateTicketQR(uint256 tokenId) internal {
        bytes32 newQRHash = keccak256(abi.encode(
            tokenId,
            ownerOf(tokenId),
            block.timestamp
        ));
        emit QRCodeUpdated(tokenId, newQRHash);
    }
    
}
