// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./MizuPassIdentity.sol";
import "./interfaces/IEventContract.sol";
import "./interfaces/IUniswap.sol";

contract EventContract is ERC721, Ownable, ReentrancyGuard, IEventContract {
    MizuPassIdentity public immutable identityContract;
    IERC20 public immutable jpymToken;
    
    address public immutable platformWallet;    
    address public immutable JPYM;

    uint8 public constant JPYM_DECIMALS = 4;
    uint256 public constant TICKET_PURCHASE_FEE_JPYM = 10000;

    EventData public eventData;
    uint256 private _tokenIdCounter;

    mapping(uint256 => bool) public hasAttended;
    mapping(uint256 => uint256) public originalPurchasePrice;
    mapping(address => bool) public ticketPurchased;

    struct PendingPayment {
        address organizer;
        address stealthAddress;
        address buyer;
        uint256 ticketPrice;
        uint256 platformFee;
        uint256 timestamp;
        bool isPaid;
    }

    mapping(address => PendingPayment) public pendingPayments;

    event EventMetadataUpdated(string newIpfsHash);
    event EventDateUpdated(uint256 newEventDate);
    event MaxTicketsUpdated(uint256 newMaxTickets);
    event StealthAddressReadyToPay(
        address indexed stealthAddress,
        address indexed organizer,
        uint256 jpymAmount
    );
    event StealthAddressFunded(
        address indexed stealthAddress,
        address indexed buyer,
        uint256 gasAmount
    );
    event PaymentPending(
        address indexed stealthAddress,
        uint256 totalCost
    );
    event PaymentCompleted(
        address indexed stealthAddress,
        uint256 tokenId
    );

    modifier onlyRegularUsers() {
        require(
            identityContract.isRegularUser(msg.sender),
            "Not a regular user"
        );
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
        address _jpymToken,
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
        require(_jpymToken != address(0), "Invalid JPYM token");
        require(_organizer != address(0), "Invalid organizer");
        require(bytes(_ipfsHash).length > 0, "Invalid IPFS hash");
        require(bytes(_ticketIpfsHash).length > 0, "Invalid ticket IPFS hash");
        require(_platformWallet != address(0), "Invalid platform wallet");
        require(bytes(_eventName).length > 0, "Invalid event name");
        require(bytes(_eventName).length <= 50, "Event name too long");
        require(bytes(_eventSymbol).length > 0, "Invalid event symbol");
        require(bytes(_eventSymbol).length <= 10, "Event symbol too long");

        identityContract = MizuPassIdentity(_identityContract);
        jpymToken = IERC20(_jpymToken);
        JPYM = _jpymToken;
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

    function purchaseTicket(
        address stealthAddress,
        uint256 gasAmount
    ) external payable onlyRegularUsers nonReentrant {
        require(eventData.isActive, "Event not active");
        require(eventData.ticketsSold < eventData.maxTickets, "Sold out");
        require(block.timestamp < eventData.eventDate, "Event has passed");
        require(stealthAddress != address(0), "Invalid stealth address");
        require(
            stealthAddress != msg.sender,
            "Stealth address cannot be sender"
        );
        require(!ticketPurchased[msg.sender], "Already purchased");
        require(gasAmount > 0, "Gas amount required");

        uint256 totalCost = eventData.ticketPrice + TICKET_PURCHASE_FEE_JPYM;

        // 1. Transfer JPYM to stealth address (for privacy)
        require(
            jpymToken.transferFrom(msg.sender, stealthAddress, totalCost),
            "JPYM transfer to stealth failed"
        );

        // 2. Send JETH gas to stealth address
        require(msg.value >= gasAmount, "Insufficient JETH for gas");
        payable(stealthAddress).transfer(gasAmount);

        // 3. Mark purchase and create pending payment
        ticketPurchased[msg.sender] = true;
        pendingPayments[stealthAddress] = PendingPayment({
            organizer: eventData.organizer,
            stealthAddress: stealthAddress,
            buyer: msg.sender,
            ticketPrice: eventData.ticketPrice,
            platformFee: TICKET_PURCHASE_FEE_JPYM,
            timestamp: block.timestamp,
            isPaid: false
        });

        // 4. Refund excess JETH
        if (msg.value > gasAmount) {
            payable(msg.sender).transfer(msg.value - gasAmount);
        }

        emit StealthAddressFunded(stealthAddress, msg.sender, gasAmount);
        emit PaymentPending(stealthAddress, totalCost);
    }

    // Function 2: Stealth address calls this to complete payment
    function completePayment() external nonReentrant {
        PendingPayment storage payment = pendingPayments[msg.sender];
        require(!payment.isPaid, "Payment already completed");
        require(payment.stealthAddress != address(0), "No pending payment");
        require(payment.stealthAddress == msg.sender, "Only stealth address can complete");

        // Stealth address pays organizer and platform
        require(
            jpymToken.transferFrom(msg.sender, payment.organizer, payment.ticketPrice),
            "Payment to organizer failed"
        );
        require(
            jpymToken.transferFrom(msg.sender, platformWallet, payment.platformFee),
            "Platform fee transfer failed"
        );

        // Mint ticket to stealth address
        uint256 tokenId = _tokenIdCounter++;
        eventData.ticketsSold++;
        originalPurchasePrice[tokenId] = payment.ticketPrice;
        _safeMint(msg.sender, tokenId);

        // Mark as paid
        payment.isPaid = true;

        emit TicketPurchased(msg.sender, tokenId, payment.ticketPrice);
        emit PaymentCompleted(msg.sender, tokenId);
    }

    // Emergency fallback: Allow buyer to complete after 24 hours
    function emergencyCompletePayment(address stealthAddress) external nonReentrant {
        PendingPayment storage payment = pendingPayments[stealthAddress];
        require(msg.sender == payment.buyer, "Only original buyer");
        require(!payment.isPaid, "Payment already completed");
        require(block.timestamp > payment.timestamp + 86400, "Wait 24 hours");

        // Complete payment as emergency fallback
        require(
            jpymToken.transferFrom(stealthAddress, payment.organizer, payment.ticketPrice),
            "Payment to organizer failed"
        );
        require(
            jpymToken.transferFrom(stealthAddress, platformWallet, payment.platformFee),
            "Platform fee transfer failed"
        );

        // Mint ticket to stealth address
        uint256 tokenId = _tokenIdCounter++;
        eventData.ticketsSold++;
        originalPurchasePrice[tokenId] = payment.ticketPrice;
        _safeMint(stealthAddress, tokenId);

        // Mark as paid
        payment.isPaid = true;

        emit TicketPurchased(stealthAddress, tokenId, payment.ticketPrice);
        emit PaymentCompleted(stealthAddress, tokenId);
    }

    function purchaseTicketDirect() external onlyRegularUsers nonReentrant {
        require(eventData.isActive, "Event not active");
        require(eventData.ticketsSold < eventData.maxTickets, "Sold out");
        require(block.timestamp < eventData.eventDate, "Event has passed");
        require(!ticketPurchased[msg.sender], "Already purchased");

        require(
            jpymToken.transferFrom(msg.sender, eventData.organizer, eventData.ticketPrice),
            "Payment to organizer failed"
        );
        require(
            jpymToken.transferFrom(msg.sender, platformWallet, TICKET_PURCHASE_FEE_JPYM),
            "Platform fee transfer failed"
        );

        ticketPurchased[msg.sender] = true;
        uint256 tokenId = _tokenIdCounter++;
        eventData.ticketsSold++;
        originalPurchasePrice[tokenId] = eventData.ticketPrice;
        _safeMint(msg.sender, tokenId);

        emit TicketPurchased(msg.sender, tokenId, eventData.ticketPrice);
    }

    // Utility function to check if stealth address has pending payment
    function hasPendingPayment(address stealthAddress) external view returns (bool) {
        return pendingPayments[stealthAddress].stealthAddress != address(0) && 
               !pendingPayments[stealthAddress].isPaid;
    }

    function resaleTicket(
        uint256 tokenId,
        uint256 price,
        address buyer
    ) external override onlyTicketOwner(tokenId) onlyRegularUsers nonReentrant {
        require(eventData.isActive, "Event not active");
        require(price > 0, "Invalid resale price");
        require(
            price <= eventData.ticketPrice,
            "Resale price cannot exceed original ticket price"
        );
        require(block.timestamp < eventData.eventDate, "Event has passed");
        require(!hasAttended[tokenId], "Ticket already used");
        require(buyer != address(0), "Invalid buyer address");
        require(buyer != ownerOf(tokenId), "Cannot sell to self");

        require(
            IERC20(JPYM).balanceOf(buyer) >= price,
            "Buyer has insufficient JPYM balance"
        );
        require(
            IERC20(JPYM).allowance(buyer, address(this)) >= price,
            "Buyer has insufficient JPYM allowance"
        );
        require(
            IERC20(JPYM).transferFrom(buyer, address(this), price),
            "Failed to transfer JPYM payment from buyer"
        );

        _transfer(ownerOf(tokenId), buyer, tokenId);

        IERC20(JPYM).transfer(msg.sender, price);

        emit TicketResold(tokenId, msg.sender, buyer, price);
    }

    function setEventActive(bool _isActive) external override onlyOrganizer {
        eventData.isActive = _isActive;
    }

    function markAttendance(uint256 tokenId) external onlyOrganizer {
        require(!hasAttended[tokenId], "Ticket already used");
        hasAttended[tokenId] = true;
    }

    function updateEventMetadata(
        string memory newIpfsHash
    ) external onlyOrganizer {
        require(bytes(newIpfsHash).length > 0, "Invalid IPFS hash");
        eventData.ipfsHash = newIpfsHash;
        emit EventMetadataUpdated(newIpfsHash);
    }

    function updateEventDate(uint256 newEventDate) external onlyOrganizer {
        require(newEventDate > block.timestamp, "Event date must be in future");
        require(
            eventData.ticketsSold == 0,
            "Cannot change date after tickets sold"
        );
        eventData.eventDate = newEventDate;
        emit EventDateUpdated(newEventDate);
    }

    function updateMaxTickets(uint256 newMaxTickets) external onlyOrganizer {
        require(newMaxTickets > 0, "Invalid max tickets");
        require(
            newMaxTickets >= eventData.ticketsSold,
            "Cannot reduce below sold tickets"
        );
        eventData.maxTickets = newMaxTickets;
        emit MaxTicketsUpdated(newMaxTickets);
    }

    function getEventData() external view override returns (EventData memory) {
        return eventData;
    }

    function getTicketData(
        uint256 tokenId
    )
        external
        view
        returns (address owner, bool attended, uint256 originalPrice)
    {
        return (
            ownerOf(tokenId),
            hasAttended[tokenId],
            originalPurchasePrice[tokenId]
        );
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
            require(_ownerOf(tokenId) != address(0), "URI query for nonexistent token");
            
            if (tokenId == 0) {
                return string(abi.encodePacked("https://gateway.pinata.cloud/ipfs/", eventData.ipfsHash));
            }
            
            return string(abi.encodePacked("https://gateway.pinata.cloud/ipfs/", eventData.ticketIpfsHash));
    }

    function _baseURI() internal pure override returns (string memory) {
        return "";
    }
}