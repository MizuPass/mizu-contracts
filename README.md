# MizuPass - Privacy-First Event Ticketing System

MizuPass is a decentralized event ticketing platform built on Scroll that prioritizes user privacy through stealth addresses and integrates with Mizuhiki SBT for identity verification. The system uses JPYM (Japanese Yen Mizuhiki) tokens for all payments and fees.

## 🏗️ Architecture Overview

The MizuPass system consists of five core smart contracts:

### Core Contracts

1. **MizuPassIdentity** - Identity verification and role management
2. **EventRegistry** - Central registry for event creation and management
3. **EventContract** - Individual event ticketing contracts (ERC721)
4. **StealthAddressManager** - Privacy-preserving address generation
5. **MockJPYM** - ERC20 token for payments (4 decimals)

## 🔐 Identity & Access Control

### User Roles
- **Event Creator**: Can create and manage events
- **Regular User**: Can purchase and resell tickets
- **None**: Unregistered users

### Verification Methods
1. **Mizuhiki SBT**: Hold a Mizuhiki Soul Bound Token
2. **ZK Passport**: Register with a unique identifier
3. **DEX Whitelist**: Whitelisted DEX addresses

### Registration Flow
```solidity
// 1. Verify identity (Mizuhiki SBT, ZK Passport, or DEX whitelist)
// 2. Register user role
```

## 🎫 Event Management

### Event Creation
Event creators must pay a **10,000 JPYM** fee to create events.

**Event Parameters:**
- IPFS hash for event metadata
- IPFS hash for ticket metadata
- Ticket price (in JPYM)
- Maximum tickets
- Event date
- Event name (max 50 chars)
- Event symbol (max 10 chars)

### Event Lifecycle
1. **Creation**: Event creator pays fee and deploys EventContract
2. **Active**: Tickets can be purchased
3. **Inactive**: Event creator can pause ticket sales
4. **Completed**: Event date passes

## 🎟️ Ticket System

### Ticket Purchase Flow
1. **User Approval**: User approves JPYM spending
2. **Stealth Address**: User provides stealth address for privacy
3. **Payment**: User pays ticket price + 10,000 JPYM fee
4. **Gas Funding**: User sends JETH for stealth address gas
5. **Completion**: Stealth address completes payment and mints ticket

### Privacy Features
- **Stealth Addresses**: Tickets are minted to stealth addresses
- **Two-Step Payment**: Payment goes through stealth address for privacy
- **Emergency Fallback**: 24-hour timeout for payment completion

### Ticket Resale
- Tickets can be resold at or below original price
- Only unused tickets (not marked as attended) can be resold
- Direct JPYM payment between buyer and seller

## 💰 Payment System

### JPYM Token (MockJPYM)
- **Symbol**: JPYM
- **Name**: Japanese Yen Mizuhiki
- **Decimals**: 4
- **Total Supply**: 10,000,000 JPYM

### Fees
- **Event Creation**: 10,000 JPYM (1 yen equivalent)
- **Ticket Purchase**: 10,000 JPYM (1 yen equivalent)

### Airdrop System
- **Standard Airdrop**: 1,000 JPYM per address (one-time)
- **Custom Airdrop**: Up to 10,000 JPYM per address (one-time)
- **One-time Only**: Each address can only claim once

## 🔒 Privacy & Security

### Stealth Address System
- **Elliptic Curve Cryptography**: Uses secp256k1 curve
- **Meta Addresses**: Users register spending/viewing key pairs
- **Ephemeral Keys**: Generate unique stealth addresses per transaction
- **View Tags**: Enable efficient scanning for incoming transactions

### Security Features
- **ReentrancyGuard**: Prevents reentrancy attacks
- **Access Control**: Role-based permissions
- **Input Validation**: Comprehensive parameter validation
- **Emergency Functions**: Fallback mechanisms for edge cases

## 🚀 Deployment

### Prerequisites
- Node.js and npm
- Hardhat
- Scroll network access

### Deploy Commands
```bash
# Install dependencies
npm install

# Compile contracts
npx hardhat compile

# Deploy to Scroll
npx hardhat ignition deploy ignition/modules/MizuPassModule.ts --network scroll
```

### Deployment Order
1. MizuPassIdentity
2. StealthAddressManager
3. MockJPYM
4. EventRegistry
5. Configuration (JPYM address, platform wallet)

## 📱 Usage Examples

### For Event Creators
```solidity
// 1. Register as event creator
identityContract.registerUserRole(UserRole.EventCreator);

// 2. Approve JPYM spending
jpymToken.approve(eventRegistry, 10000);

// 3. Create event
eventRegistry.createEvent(
    "QmEventMetadataHash",
    "QmTicketMetadataHash", 
    50000, // 5 yen ticket price
    100,   // max tickets
    1700000000, // event date
    "Tokyo Tech Meetup",
    "TTM"
);
```

### For Regular Users
```solidity
// 1. Register as regular user
identityContract.registerUserRole(UserRole.RegularUser);

// 2. Get JPYM tokens
mockJPYM.airdrop(); // Get 1000 JPYM

// 3. Approve spending
jpymToken.approve(eventContract, 60000); // ticket price + fee

// 4. Purchase ticket
eventContract.purchaseTicket(stealthAddress, gasAmount);
```

### For Stealth Addresses
```solidity
// Complete payment (called by stealth address)
eventContract.completePayment();
```

## 🔧 Configuration

### Platform Settings
- **Platform Wallet**: `0xfd1AF2826012385a84A8E9BE8a1586293FB3980B`
- **Mizuhiki SBT Contract**: `0x606F72657e72cd1218444C69eF9D366c62C54978`

### Fee Structure
- Event creation: 10,000 JPYM (1 yen)
- Ticket purchase: 10,000 JPYM (1 yen)
- No platform fees on resales

## 🌐 IPFS Integration

- **Event Metadata**: Stored on IPFS with Pinata gateway
- **Ticket Metadata**: Stored on IPFS with Pinata gateway
- **Gateway**: `https://gateway.pinata.cloud/ipfs/`

## 🔍 Key Features

### Privacy
- Stealth addresses for ticket ownership
- Two-step payment process
- No direct link between buyer and ticket

### Decentralization
- No central authority
- Smart contract-based governance
- Immutable event records

### Scalability
- Individual event contracts
- Efficient batch operations
- Gas-optimized functions

### User Experience
- Simple airdrop system for testing
- Clear role-based access
- Emergency fallback mechanisms

## 📄 License

MIT License - see LICENSE file for details.

## 📞 Support

For questions or support, please open an issue on GitHub or contact the development team.

---

**Note**: This is a hackathon demo version with reduced fees and mock tokens for testing purposes. Production deployment would require additional security audits and real token integration.