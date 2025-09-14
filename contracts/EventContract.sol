// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./MizuPassIdentity.sol";
import "./MizuPassPaymentGateway.sol";
import "./interfaces/IEventContract.sol";
import "./interfaces/IUniswap.sol";

contract EventContract is ERC721, Ownable, ReentrancyGuard, IEventContract {
    MizuPassIdentity public immutable identityContract;
    MizuPassPaymentGateway public immutable paymentGateway;
    
    address public immutable platformWallet;
    
    uint8 public constant MJPY_DECIMALS = 4;
    uint256 public constant TICKET_PURCHASE_FEE_MJPY = 1;
    
    address public constant MJPY = 0x115e91ef61ae86FbECa4b5637FD79C806c331632;
    
    EventData public eventData;
    uint256 private _tokenIdCounter;
    
    mapping(uint256 => bool) public hasAttended;
    mapping(uint256 => uint256) public originalPurchasePrice;
    
    event EventMetadataUpdated(string newIpfsHash);
    event EventDateUpdated(uint256 newEventDate);
    event MaxTicketsUpdated(uint256 newMaxTickets);
    event StealthAddressReadyToPay(address indexed stealthAddress, address indexed organizer, uint256 mjpyAmount);

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
        string memory _ticketIpfsHash,
        uint256 _ticketPrice,
        uint256 _maxTickets,
        uint256 _eventDate,
        address _platformWallet,
        string memory _eventName,
        string memory _eventSymbol
    ) ERC721(_eventName, _eventSymbol) Ownable(_organizer) {
        require(_identityContract != address(0), "Invalid identity contract");
        require(_paymentGateway != address(0), "Invalid payment gateway");
        require(_organizer != address(0), "Invalid organizer");
        require(bytes(_ipfsHash).length > 0, "Invalid IPFS hash");
        require(bytes(_ticketIpfsHash).length > 0, "Invalid ticket IPFS hash");
        require(_platformWallet != address(0), "Invalid platform wallet");
        require(bytes(_eventName).length > 0, "Invalid event name");
        require(bytes(_eventName).length <= 50, "Event name too long");
        require(bytes(_eventSymbol).length > 0, "Invalid event symbol");
        require(bytes(_eventSymbol).length <= 10, "Event symbol too long");
        
        identityContract = MizuPassIdentity(_identityContract);
        paymentGateway = MizuPassPaymentGateway(_paymentGateway);
        platformWallet = _platformWallet;
        
        eventData = EventData({
            organizer: _organizer,
            ipfsHash: _ipfsHash,
            ticketIpfsHash: _ticketIpfsHash,
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
        
        _safeMint(_organizer, 0);
    }

    function purchaseTicket(address stealthAddress) external onlyRegularUsers nonReentrant {
        require(eventData.isActive, "Event not active");
        require(eventData.ticketsSold < eventData.maxTickets, "Sold out");
        require(block.timestamp < eventData.eventDate, "Event has passed");
        require(stealthAddress != address(0), "Invalid stealth address");
        require(stealthAddress != msg.sender, "Stealth address cannot be sender");
        
        uint256 totalPayment = eventData.ticketPrice + TICKET_PURCHASE_FEE_MJPY;
        
        require(IERC20(MJPY).balanceOf(msg.sender) >= totalPayment, "Insufficient MJPY balance for ticket purchase");
        require(IERC20(MJPY).allowance(msg.sender, address(this)) >= totalPayment, "Insufficient MJPY allowance for ticket purchase");
        require(IERC20(MJPY).transferFrom(msg.sender, address(this), totalPayment), "Failed to transfer MJPY payment");
        
        uint256 tokenId = _tokenIdCounter++;
        
        IERC20(MJPY).transfer(stealthAddress, eventData.ticketPrice);
        IERC20(MJPY).transfer(platformWallet, TICKET_PURCHASE_FEE_MJPY);
        
        _safeMint(stealthAddress, tokenId);
        
        originalPurchasePrice[tokenId] = eventData.ticketPrice;
        eventData.ticketsSold++;
        
        emit TicketPurchased(stealthAddress, tokenId, eventData.ticketPrice);
        emit StealthAddressReadyToPay(stealthAddress, eventData.organizer, eventData.ticketPrice);
    }

    function resaleTicket(
        uint256 tokenId,
        uint256 price,
        address buyer
    ) external override onlyTicketOwner(tokenId) onlyRegularUsers nonReentrant {
        require(eventData.isActive, "Event not active");
        require(price > 0, "Invalid resale price");
        require(price <= eventData.ticketPrice, "Resale price cannot exceed original ticket price");
        require(block.timestamp < eventData.eventDate, "Event has passed");
        require(!hasAttended[tokenId], "Ticket already used");
        require(buyer != address(0), "Invalid buyer address");
        require(buyer != ownerOf(tokenId), "Cannot sell to self");
        
        require(IERC20(MJPY).balanceOf(buyer) >= price, "Buyer has insufficient MJPY balance");
        require(IERC20(MJPY).allowance(buyer, address(this)) >= price, "Buyer has insufficient MJPY allowance");
        require(IERC20(MJPY).transferFrom(buyer, address(this), price), "Failed to transfer MJPY payment from buyer");
        
        _transfer(ownerOf(tokenId), buyer, tokenId);
        
        IERC20(MJPY).transfer(msg.sender, price);
        
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
        
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "URI query for nonexistent token");
        
        if (tokenId == 0) {
            return string(abi.encodePacked("ipfs://", eventData.ipfsHash));
        }
        
        return string(abi.encodePacked("ipfs://", eventData.ticketIpfsHash));
    }
    
    function _baseURI() internal pure override returns (string memory) {
        return "";
    }
}