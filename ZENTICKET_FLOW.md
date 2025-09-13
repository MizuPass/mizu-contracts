# Zenticket System Flow

## Complete System Architecture Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              ZENTICKET ECOSYSTEM                               │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   MizuPass      │    │   Event         │    │   Stealth       │
│   Identity      │    │   Registry      │    │   Address       │
│   Contract      │    │   Contract      │    │   Manager       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Event         │    │   MizuPass      │    │   Uniswap       │
│   Contract      │    │   Payment       │    │   Integration   │
│   (ERC721)      │    │   Gateway       │    │   (JETH↔MJPY)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 1. USER IDENTITY VERIFICATION FLOW

```
User Registration/Verification
├── Method 1: Mizuhiki SBT
│   └── User holds Soul Bound Token from Mizuhiki contract
├── Method 2: ZK Passport (Placeholder)
│   └── Zero-knowledge proof verification
└── Method 3: DEX Whitelist
    └── Manually whitelisted addresses

┌─────────────────┐
│ MizuPassIdentity│
│ Contract        │
├─────────────────┤
│ • isVerifiedUser│
│ • verifySBT     │
│ • verifyZK      │
│ • updateDexList │
└─────────────────┘
```

## 2. EVENT CREATION FLOW

```
Verified User
    │
    ▼
┌─────────────────┐
│ EventRegistry   │
│ .createEvent()  │
├─────────────────┤
│ • Pay 0.01 ETH  │
│ • Set params    │
│ • Deploy new    │
│   EventContract │
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ EventContract   │
│ (ERC721)        │
├─────────────────┤
│ • Event details │
│ • Ticket price  │
│ • Max tickets   │
│ • Resale rules  │
└─────────────────┘
```

## 3. TICKET PURCHASE FLOW

```
User
    │
    ▼
┌─────────────────┐
│ Generate Stealth│
│ Address         │
├─────────────────┤
│ • spendKey      │
│ • viewKey       │
│ • randomness    │
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ EventContract   │
│ .purchaseTicket │
│ (stealthAddr)   │
├─────────────────┤
│ • Mint ERC721   │
│ • Record owner  │
│ • Call payment  │
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ PaymentGateway  │
│ .purchaseTicket │
│ WithJETH()      │
├─────────────────┤
│ • Receive JETH  │
│ • Swap JETH→MJPY│
│ • Send to stealth│
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ Uniswap V3      │
│ Swap            │
├─────────────────┤
│ • JETH → MJPY   │
│ • 0.3% fee tier │
│ • Exact output  │
└─────────────────┘
```

## 4. TICKET RESALE FLOW

```
Ticket Owner
    │
    ▼
┌─────────────────┐
│ EventContract   │
│ .resaleTicket() │
├─────────────────┤
│ • Check price   │
│ • Validate      │
│ • Transfer NFT  │
│ • Update QR     │
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ PaymentGateway  │
│ (Same as above) │
└─────────────────┘
```

## 5. PRIVACY FEATURES

```
Stealth Address Generation
├── Elliptic Curve Cryptography
├── One-time addresses per transaction
├── Unlinkable transactions
└── Privacy-preserving payments

Payment Privacy
├── All payments → Stealth addresses
├── JETH → MJPY swaps via Uniswap
├── No direct identity links
└── Private transaction history
```

## 6. EVENT MANAGEMENT FLOW

```
Event Organizer
    │
    ▼
┌─────────────────┐
│ EventContract   │
│ Management      │
├─────────────────┤
│ • setEventActive│
│ • updateResale  │
│ • markAttendance│
│ • withdraw funds│
└─────────────────┘
```

## 7. COMPLETE USER JOURNEY

```
1. User Verification
   └── Get verified via MizuPassIdentity

2. Event Discovery
   └── Browse events in EventRegistry

3. Ticket Purchase
   ├── Generate stealth address
   ├── Call purchaseTicket()
   ├── Pay with JETH
   ├── Receive MJPY at stealth address
   └── Get ERC721 ticket

4. Event Attendance
   ├── Show ticket QR code
   ├── Organizer marks attendance
   └── Prevent double-use

5. Optional Resale
   ├── List ticket for resale
   ├── New buyer purchases
   ├── Transfer to new stealth address
   └── Update QR code
```

## 8. TOKEN ECONOMICS

```
Payment Tokens
├── JETH (Wrapped ETH) - Primary payment
├── MJPY (Japanese Yen) - Ticket pricing
└── ETH - Gas fees & creation fees

Fees Structure
├── Event Creation: 0.01 ETH
├── Uniswap Swap: 0.3% fee tier
├── Resale Royalty: Configurable %
└── Gas Costs: Standard Ethereum
```

## 9. SECURITY FEATURES

```
Access Control
├── Only verified users
├── Owner-only functions
├── Ticket owner validation
└── Organizer permissions

Protection Mechanisms
├── ReentrancyGuard
├── Event date validation
├── Price controls
├── Attendance tracking
└── Payment deduplication
```

## 10. CONTRACT INTERACTIONS

```
MizuPassIdentity
├── Verifies all users
├── Manages SBT verification
├── Handles ZK proofs
└── Maintains DEX whitelist

EventRegistry
├── Creates new events
├── Tracks event contracts
├── Manages creation fees
└── Links organizers to events

EventContract (ERC721)
├── Mints ticket NFTs
├── Handles purchases/resales
├── Manages event data
└── Tracks attendance

MizuPassPaymentGateway
├── Processes JETH payments
├── Executes Uniswap swaps
├── Sends MJPY to stealth addresses
└── Prevents payment duplication

StealthAddressManager
├── Generates stealth addresses
├── Manages privacy keys
├── Handles stealth payments
└── Verifies ownership
```

---

## Key Benefits

✅ **Privacy-Preserving**: Stealth addresses break transaction links
✅ **Decentralized**: No central authority controls tickets
✅ **Transparent**: All transactions on-chain
✅ **Flexible**: Configurable resale controls
✅ **Secure**: Multiple verification methods
✅ **Efficient**: Automated payment processing
✅ **User-Friendly**: Simple purchase flow
✅ **Anti-Fraud**: Attendance tracking prevents double-use
