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
        uint256 mjpyRequired,
        uint256 deadline
    ) external payable onlyVerifiedUsers {
        require(stealthAddress != address(0), "Invalid stealth address");
        require(mjpyRequired > 0, "Invalid amount");
        require(deadline > block.timestamp, "Deadline passed");
        
        bytes memory path = abi.encodePacked(WJETH, uint24(FEE_TIER), MJPY);
        uint256 jethNeeded = _quoteExactOutput(path, mjpyRequired);
        require(msg.value >= jethNeeded, "Insufficient JETH");
        
        uint256 mjpyReceived = _executePrivateSwap(
            msg.value,
            mjpyRequired,
            stealthAddress,
            deadline
        );
        
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
            jethNeeded,
            mjpyReceived,
            paymentHash
        );
        
        emit TicketPurchased(ticketId, msg.sender, stealthAddress, mjpyReceived);
        
        if (msg.value > jethNeeded) {
            payable(msg.sender).transfer(msg.value - jethNeeded);
        }
    }
    
    function _executePrivateSwap(
        uint256 jethAmount,
        uint256 mjpyTarget,
        address stealthAddr,
        uint256 deadline
    ) internal returns (uint256) {
        ISwapRouter02.ExactOutputSingleParams memory params =
            ISwapRouter02.ExactOutputSingleParams({
                tokenIn: WJETH,
                tokenOut: MJPY,
                fee: FEE_TIER,
                recipient: address(this),
                deadline: deadline,
                amountOut: mjpyTarget,
                amountInMaximum: jethAmount,
                sqrtPriceLimitX96: 0
            });
        
        ROUTER.exactOutputSingle{value: jethAmount}(params);
        
        _transferThroughMixer(MJPY, mjpyTarget, stealthAddr);
        
        return mjpyTarget;
    }
    
    function _transferThroughMixer(
        address token,
        uint256 amount,
        address stealthAddr
    ) internal {
        IERC20(token).transfer(stealthAddr, amount);
    }
    
    function _quoteExactOutput(bytes memory path, uint256 amountOut) internal returns (uint256) {
        IQuoterV2.QuoteExactOutputParams memory params = IQuoterV2.QuoteExactOutputParams({
            path: path,
            amountOut: amountOut,
            sqrtPriceLimitX96: 0
        });
        
        (uint256 amountIn, , , ) = QUOTER.quoteExactOutput(params);
        return amountIn;
    }
    
    function getPaymentStatus(bytes32 paymentHash) external view returns (bool) {
        return processedPayments[paymentHash];
    }
    
    function quoteJETHForMJPY(uint256 mjpyAmount) external returns (uint256 jethNeeded) {
        bytes memory path = abi.encodePacked(WJETH, uint24(FEE_TIER), MJPY);
        return _quoteExactOutput(path, mjpyAmount);
    }
}