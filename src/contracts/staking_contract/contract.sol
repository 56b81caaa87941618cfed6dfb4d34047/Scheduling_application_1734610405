
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract staking_contract is ReentrancyGuard, Ownable {
    IERC20 public immutable stakingToken;
    uint256 public rewardRate = 100; // 100 tokens per second
    uint256 public constant COOLDOWN_PERIOD = 1 days;

    mapping(address => uint256) public stakes;
    mapping(address => uint256) public stakingTime;
    mapping(address => uint256) public lastUnstakeTime;

    uint256 public totalStaked;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);

    constructor() Ownable() {
        stakingToken = IERC20(0x5FbDB2315678afecb367f032d93F642f64180aa3); // Example token address
    }

    function stake(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Cannot stake 0 tokens");
        require(stakingToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        if (stakes[msg.sender] > 0) {
            claimRewards();
        }

        stakes[msg.sender] += _amount;
        stakingTime[msg.sender] = block.timestamp;
        totalStaked += _amount;

        emit Staked(msg.sender, _amount);
    }

    function unstake(uint256 _amount) external nonReentrant {
        require(stakes[msg.sender] >= _amount, "Insufficient staked amount");
        require(block.timestamp >= lastUnstakeTime[msg.sender] + COOLDOWN_PERIOD, "Cooldown period not elapsed");

        claimRewards();

        stakes[msg.sender] -= _amount;
        totalStaked -= _amount;
        lastUnstakeTime[msg.sender] = block.timestamp;

        require(stakingToken.transfer(msg.sender, _amount), "Transfer failed");

        emit Unstaked(msg.sender, _amount);
    }

    function claimRewards() public {
        uint256 reward = calculateRewards(msg.sender);
        if (reward > 0) {
            stakingTime[msg.sender] = block.timestamp;
            require(stakingToken.transfer(msg.sender, reward), "Reward transfer failed");
            emit RewardsClaimed(msg.sender, reward);
        }
    }

    function calculateRewards(address _user) public view returns (uint256) {
        uint256 stakedAmount = stakes[_user];
        if (stakedAmount == 0) {
            return 0;
        }
        uint256 stakingDuration = block.timestamp - stakingTime[_user];
        return (stakedAmount * stakingDuration * rewardRate) / 1e18;
    }

    function updateRewardRate(uint256 _newRate) external onlyOwner {
        rewardRate = _newRate;
        emit RewardRateUpdated(_newRate);
    }

    function getStakeInfo(address _user) external view returns (uint256 staked, uint256 rewards) {
        staked = stakes[_user];
        rewards = calculateRewards(_user);
    }
}
