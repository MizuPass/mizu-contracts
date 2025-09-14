// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockJPYM is ERC20, Ownable {
    uint8 private _decimals;
    mapping(address => bool) public hasClaimedAirdrop;
    
    constructor() ERC20("Japanese Yen Mizuhiki", "JPYM") Ownable(msg.sender) {
        _decimals = 4;
        _mint(msg.sender, 10000000 * 10**_decimals);
    }
    
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    function mintToMultiple(address[] calldata recipients, uint256 amount) external onlyOwner {
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amount);
        }
    }
    
    function airdrop() external {
        require(!hasClaimedAirdrop[msg.sender], "Address has already claimed airdrop");
        uint256 airdropAmount = 1000 * 10**_decimals;
        hasClaimedAirdrop[msg.sender] = true;
        _mint(msg.sender, airdropAmount);
    }
    
    function airdropCustom(uint256 amount) external {
        require(!hasClaimedAirdrop[msg.sender], "Address has already claimed airdrop");
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= 10000 * 10**_decimals, "Maximum airdrop is 10,000 JPYM");
        hasClaimedAirdrop[msg.sender] = true;
        _mint(msg.sender, amount);
    }
}