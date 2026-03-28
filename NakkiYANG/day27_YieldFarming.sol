// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC20Metadata {
    function decimals() external view returns (uint8);
}

contract YieldFarming is ReentrancyGuard {
    IERC20 public stakingToken;
    IERC20 public rewardToken;
    uint256 public rewardRatePerSecond;
    address public owner;
    
    uint8 public stakingTokenDecimals;
    
    struct StakerInfo {
        uint256 stakedAmount;
        uint256 rewardDebt;
        uint256 lastUpdateTime;
    }
    
    mapping(address => StakerInfo) public stakers;
    
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event RewardRefilled(uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor(
        address _stakingToken,
        address _rewardToken,
        uint256 _rewardRatePerSecond
    ) {
        require(_stakingToken != address(0), "Invalid staking token");
        require(_rewardToken != address(0), "Invalid reward token");
        require(_rewardRatePerSecond > 0, "Invalid reward rate");
        
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        rewardRatePerSecond = _rewardRatePerSecond;
        owner = msg.sender;
        
        stakingTokenDecimals = IERC20Metadata(_stakingToken).decimals();
    }
    
    // 质押代币
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0");
        
        updateRewards(msg.sender);
        
        stakingToken.transferFrom(msg.sender, address(this), amount);
        stakers[msg.sender].stakedAmount += amount;
        
        emit Staked(msg.sender, amount);
    }
    
    // 取消质押
    function unstake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot unstake 0");
        require(stakers[msg.sender].stakedAmount >= amount, "Insufficient balance");
        
        updateRewards(msg.sender);
        
        stakers[msg.sender].stakedAmount -= amount;
        stakingToken.transfer(msg.sender, amount);
        
        emit Unstaked(msg.sender, amount);
    }
    
    // 领取奖励
    function claimRewards() external nonReentrant {
        updateRewards(msg.sender);
        
        uint256 reward = stakers[msg.sender].rewardDebt;
        require(reward > 0, "No rewards");
        
        stakers[msg.sender].rewardDebt = 0;
        rewardToken.transfer(msg.sender, reward);
        
        emit RewardClaimed(msg.sender, reward);
    }
    
    // 紧急提取（放弃奖励）
    function emergencyWithdraw() external nonReentrant {
        uint256 amount = stakers[msg.sender].stakedAmount;
        require(amount > 0, "No stake");
        
        stakers[msg.sender].stakedAmount = 0;
        stakers[msg.sender].rewardDebt = 0;
        stakers[msg.sender].lastUpdateTime = 0;
        
        stakingToken.transfer(msg.sender, amount);
        
        emit EmergencyWithdraw(msg.sender, amount);
    }
    
    // 管理员充值奖励
    function refillRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "Cannot refill 0");
        
        rewardToken.transferFrom(msg.sender, address(this), amount);
        
        emit RewardRefilled(amount);
    }
    
    // 更新用户奖励
    function updateRewards(address user) internal {
        StakerInfo storage staker = stakers[user];
        
        if (staker.stakedAmount > 0) {
            uint256 pending = pendingRewards(user);
            staker.rewardDebt += pending;
        }
        
        staker.lastUpdateTime = block.timestamp;
    }
    
    // 计算待领取奖励
    function pendingRewards(address user) public view returns (uint256) {
        StakerInfo memory staker = stakers[user];
        
        if (staker.stakedAmount == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - staker.lastUpdateTime;
        if (timeElapsed == 0) return 0;
        
        // 奖励 = 质押量 × 奖励率 × 时间
        uint256 reward = (staker.stakedAmount * rewardRatePerSecond * timeElapsed)
            / (10 ** stakingTokenDecimals);
        
        return reward;
    }
    
    // 获取用户总奖励（包括待领取）
    function getTotalRewards(address user) external view returns (uint256) {
        return stakers[user].rewardDebt + pendingRewards(user);
    }
    
    // 获取质押代币小数位数
    function getStakingTokenDecimals() external view returns (uint8) {
        return stakingTokenDecimals;
    }
    
    // 获取合约奖励余额
    function getRewardBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }
}