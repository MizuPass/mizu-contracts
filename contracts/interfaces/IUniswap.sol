// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);
}

interface IQuoterV2 {
    struct QuoteExactInputParams {
        bytes path;
        uint256 amountIn;
        uint160 sqrtPriceLimitX96;
    }
        
    function quoteExactInput(QuoteExactInputParams memory params)
        external
        returns (
            uint256 amountOut,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        );
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}
