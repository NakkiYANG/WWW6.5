// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2Plus.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DecentralisedLottery is VRFConsumerBaseV2Plus, Ownable {
    // 彩票状态
    enum LOTTERY_STATE { OPEN, CLOSED, CALCULATING }
    
    LOTTERY_STATE public lotteryState;
    address payable[] public players;
    address public recentWinner;
    uint256 public entryFee;
    
    // Chainlink VRF配置
    VRFCoordinatorV2Interface private vrfCoordinator;
    uint256 public subscriptionId;
    bytes32 public keyHash;
    uint32 public callbackGasLimit = 100000;
    uint16 public requestConfirmations = 3;
    uint32 public numWords = 1;
    uint256 public latestRequestId;
    
    // 事件
    event LotteryEntered(address indexed player, uint256 entryFee);
    event LotteryStarted();
    event LotteryEnded();
    event RandomnessRequested(uint256 indexed requestId);
    event WinnerPicked(address indexed winner, uint256 prize);
    
    constructor(
        address vrfCoordinatorAddress,
        uint256 _subscriptionId,
        bytes32 _keyHash,
        uint256 _entryFee
    ) VRFConsumerBaseV2Plus(vrfCoordinatorAddress) Ownable(msg.sender) {
        vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorAddress);
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        entryFee = _entryFee;
        lotteryState = LOTTERY_STATE.CLOSED;
    }
    
    // 参与彩票
    function enter() public payable {
        require(lotteryState == LOTTERY_STATE.OPEN, "Lottery not open");
        require(msg.value >= entryFee, "Not enough ETH to enter");
        
        players.push(payable(msg.sender));
        emit LotteryEntered(msg.sender, msg.value);
    }
    
    // 开始彩票
    function startLottery() public onlyOwner {
        require(lotteryState == LOTTERY_STATE.CLOSED, "Lottery already started");
        
        lotteryState = LOTTERY_STATE.OPEN;
        emit LotteryStarted();
    }
    
    // 结束彩票并请求随机数
    function endLottery() public onlyOwner {
        require(lotteryState == LOTTERY_STATE.OPEN, "Lottery not open");
        require(players.length > 0, "No players in lottery");
        
        lotteryState = LOTTERY_STATE.CALCULATING;
        
        // 请求随机数
        latestRequestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        
        emit RandomnessRequested(latestRequestId);
        emit LotteryEnded();
    }
    
    // VRF回调函数 - 选择获胜者
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) 
        internal override {
        
        require(lotteryState == LOTTERY_STATE.CALCULATING, "Not calculating winner");
        require(randomWords.length > 0, "No random words received");
        
        // 选择获胜者
        uint256 indexOfWinner = randomWords[0] % players.length;
        recentWinner = players[indexOfWinner];
        
        // 发送奖金
        uint256 prize = address(this).balance;
        (bool success, ) = recentWinner.call{value: prize}("");
        require(success, "Prize transfer failed");
        
        // 重置彩票
        players = new address payable[](0);
        lotteryState = LOTTERY_STATE.CLOSED;
        
        emit WinnerPicked(recentWinner, prize);
    }
    
    // 获取参与者数量
    function getNumberOfPlayers() public view returns (uint256) {
        return players.length;
    }
    
    // 获取参与者列表
    function getPlayers() public view returns (address payable[] memory) {
        return players;
    }
    
    // 获取奖池金额
    function getPrizePool() public view returns (uint256) {
        return address(this).balance;
    }
    
    // 检查是否为参与者
    function isPlayer(address _player) public view returns (bool) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == _player) {
                return true;
            }
        }
        return false;
    }
    
    // 更新入场费
    function setEntryFee(uint256 _newEntryFee) public onlyOwner {
        require(lotteryState == LOTTERY_STATE.CLOSED, "Cannot change fee during lottery");
        entryFee = _newEntryFee;
    }
    
    // 更新VRF参数
    function setVRFConfig(
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations
    ) public onlyOwner {
        require(lotteryState == LOTTERY_STATE.CLOSED, "Cannot change config during lottery");
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;
    }
    
    // 紧急提取（仅在关闭状态）
    function emergencyWithdraw() public onlyOwner {
        require(lotteryState == LOTTERY_STATE.CLOSED, "Lottery must be closed");
        require(players.length == 0, "Players still in lottery");
        
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }
    
    // 获取彩票状态字符串
    function getLotteryState() public view returns (string memory) {
        if (lotteryState == LOTTERY_STATE.OPEN) return "OPEN";
        if (lotteryState == LOTTERY_STATE.CLOSED) return "CLOSED";
        if (lotteryState == LOTTERY_STATE.CALCULATING) return "CALCULATING";
        return "UNKNOWN";
    }
}