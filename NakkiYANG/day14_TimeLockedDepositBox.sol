// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./day14_BaseDepositBox.sol";

contract TimeLockedDepositBox is BaseDepositBox {
    uint256 public unlockTime;
    
    constructor(string memory _metadata, uint256 _lockDuration) 
        BaseDepositBox(_metadata) 
    {
        unlockTime = block.timestamp + _lockDuration;
    }
    
    modifier timeUnlocked() {
        require(block.timestamp >= unlockTime, "Still locked");
        _;
    }
    
    // 重写父合约函数,添加时间锁
    function getSecret() external view override onlyOwner timeUnlocked 
        returns (string memory) 
    {
        return super.getSecret();
    }
    
    function getBoxType() external pure override returns (string memory) {
        return "Time-Locked";
    }
}
