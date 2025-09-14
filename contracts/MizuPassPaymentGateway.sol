// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./MizuPassIdentity.sol";
import "./StealthAddressManager.sol";
import "./interfaces/IUniswap.sol";

contract MizuPassPaymentGateway {
    MizuPassIdentity public immutable identityContract;
    StealthAddressManager public immutable stealthManager;
    
    ISwapRouter02 public constant ROUTER = ISwapRouter02(0xB1A252f0c064c730de7dE55Db2e4BC4517750d23);
    IQuoterV2 public constant QUOTER = IQuoterV2(0x5c46f6A3F74F534c99E476f627732FEB81a10Fee);
    
    address public constant WJETH = 0x06ef058302dd8449c471d8f4B4397CAaFfBa3B47;
    address public constant MJPY = 0x115e91ef61ae86FbECa4b5637FD79C806c331632;
    
    uint24 public constant FEE_TIER = 3000;
    
    mapping(bytes32 => bool) public processedPayments;
    
    event PaymentProcessed(
        address indexed payer,
        address indexed recipient,
        uint256 jethAmount,
        uint256 mjpyAmount,
        bytes32 paymentHash
    );
    
    event TicketPurchased(
        uint256 indexed ticketId,
        address indexed buyer,
        address stealthAddress,
        uint256 mjpyAmount
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
        uint256 jethAmount,
        uint256 deadline
    ) external payable onlyVerifiedUsers {
        require(msg.value >= jethAmount, "Insufficient JETH payment");
        require(stealthAddress != address(0), "Invalid stealth address");
        require(jethAmount > 0, "Invalid amount");
        require(deadline > block.timestamp, "Deadline passed");
        
        uint256 mjpyReceived = _executeDirectSwap(jethAmount, deadline);
        
        _transferThroughMixer(MJPY, mjpyReceived, stealthAddress);
        
        bytes32 paymentHash = keccak256(abi.encode(
            msg.sender,
            stealthAddress,
            mjpyReceived,
            block.timestamp
        ));
        
        require(!processedPayments[paymentHash], "Payment already processed");
        processedPayments[paymentHash] = true;
        
        emit PaymentProcessed(
            msg.sender,
            stealthAddress,
            jethAmount,
            mjpyReceived,
            paymentHash
        );
        
        emit TicketPurchased(ticketId, msg.sender, stealthAddress, mjpyReceived);
        
        if (msg.value > jethAmount) {
            payable(msg.sender).transfer(msg.value - jethAmount);
        }
    }
    
    function _executeDirectSwap(
        uint256 jethAmount,
        uint256 deadline
    ) internal returns (uint256) {
        uint256 expectedMJPY = _quoteExactInput(jethAmount);
        uint256 minMJPY = (expectedMJPY * 99) / 100;
        
        ISwapRouter02.ExactInputSingleParams memory params =
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: WJETH,
                tokenOut: MJPY,
                fee: FEE_TIER,
                recipient: address(this),
                deadline: deadline,
                amountIn: jethAmount,
                amountOutMinimum: minMJPY,
                sqrtPriceLimitX96: 0
            });
        
        uint256 mjpyReceived = ROUTER.exactInputSingle{value: jethAmount}(params);
        
        return mjpyReceived;
    }

    function _transferThroughMixer(
        address token,
        uint256 amount,
        address stealthAddr
    ) internal {
        IERC20(token).transfer(stealthAddr, amount);
    }
    
    function _quoteExactInput(uint256 amountIn) internal returns (uint256) {
        bytes memory path = abi.encodePacked(WJETH, uint24(FEE_TIER), MJPY);
        
        IQuoterV2.QuoteExactInputParams memory params = IQuoterV2.QuoteExactInputParams({
            path: path,
            amountIn: amountIn,
            sqrtPriceLimitX96: 0
        });
        
        (uint256 amountOut, , , ) = QUOTER.quoteExactInput(params);
        return amountOut;
    }
    
    function getPaymentStatus(bytes32 paymentHash) external view returns (bool) {
        return processedPayments[paymentHash];
    }
    
    function quoteJETHForMJPY(uint256 jethAmount) external returns (uint256 mjpyExpected) {
        return _quoteExactInput(jethAmount);
    }
    
    function generateStealthAddress(
        address recipientMetaAddress,
        uint256 ephemeralPrivKey
    ) external view returns (
        address stealthAddress,
        uint256 ephemeralPubKeyPrefix,
        uint256 ephemeralPubKey,
        bytes1 viewTag
    ) {
        return stealthManager.generateStealthAddress(recipientMetaAddress, ephemeralPrivKey);
    }
}