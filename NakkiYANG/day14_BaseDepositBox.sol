// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./day14_IDepositBox.sol";

abstract contract BaseDepositBox is IDepositBox {
    address public owner;
    string public metadata;
    string private secret;
    uint256 public depositTime;
    
    constructor(string memory _metadata) {
        owner = msg.sender;
        metadata = _metadata;
        depositTime = block.timestamp;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    // 实现的函数
    function getOwner() external view override returns (address) {
        return owner;
    }
    
    function storeSecret(string memory _secret) external override onlyOwner {
        secret = _secret;
    }
    
    // 抽象函数 - 子类必须实现
    function getBoxType() external pure virtual override returns (string memory);
}