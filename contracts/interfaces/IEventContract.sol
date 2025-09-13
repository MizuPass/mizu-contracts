// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IEventContract {
    struct EventData {
        address organizer;
        string ipfsHash;
        uint256 ticketPrice;
        uint256 maxTickets;
        uint256 ticketsSold;
        bool isActive;
        uint256 eventDate;
    }
    
    event EventCreated(
        address indexed organizer,
        string ipfsHash,
        uint256 ticketPrice,
        uint256 maxTickets,
        uint256 eventDate
    );
    
    event TicketPurchased(
        address indexed buyer,
        uint256 indexed ticketId,
        uint256 price
    );
    
    event TicketResold(
        uint256 indexed ticketId,
        address indexed from,
        address indexed to,
        uint256 price
    );
    
    function getEventData() external view returns (EventData memory);
    function purchaseTicket(address stealthAddress) external payable;
    function resaleTicket(uint256 ticketId, uint256 price, address buyer) external payable;
    function setEventActive(bool _isActive) external;
}
