// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "./Token/Rijent.sol";

contract STAKING is Rijent {
    uint256 public StakeTime;
    uint256 public interestPerSecond;
    Rijent public stakingToken;
    uint256 private totalRewardTime;
    uint256 private rewardAvailable;
    uint256 public rewardGeneratedTime;
    uint256 private stakedAmount;
    uint256 private secInMonth = 10;
    uint256 private _stakeMonth;
    uint256 public rewardGeneratedFor;
    uint256 public coolingTime;
    uint256 public stakePerWEEK;
    uint256 public weekOfClaim;

    uint256 public timeAfterStakeFinish;
    uint256 public amountStakeClaimable;

    mapping(address => uint256) _balances;
    mapping(address => uint256) _stakedMoney;
    mapping(address => uint256) public totalreward;
    mapping(address => uint256) public totalRewardedAmount;
    mapping(address => uint256) private claimableReward;
    mapping(address => uint256[]) public lastRewardTime;
    uint256[] private _lastRewardTime;
    mapping(address => uint256) public totalclaimed;
    mapping(address => uint256) private claimableStakeLeft;
    uint256 public ClaimMature;

    constructor(address _stakingToken) {
        stakingToken = Rijent(_stakingToken);
    }

    function stake(
        uint256 amount,
        uint256 months,
        uint256 _interest
    ) public {
        require(
            months == 1 || months == 2 || months == 3 || months == 4,
            "Invalid Input"
        );
        require(amount > 100, "minimum stake is 100");
        _stakeMonth = months;
        stakedAmount += amount;
        StakeTime = block.timestamp;
        coolingTime = StakeTime + _stakeMonth * secInMonth;
        _stakedMoney[msg.sender] = amount;
        Rijent.transferPrice(msg.sender, address(this), amount);
        require(
            (_interest == 3 && _stakeMonth == 1) ||
                (_interest == 4 && _stakeMonth == 2) ||
                (_interest == 5 && _stakeMonth == 3) ||
                (_interest == 6 && _stakeMonth == 6),
            "Invalid Input"
        );
        uint256 totalRewardGeneratead = (((_interest *
            _stakedMoney[msg.sender]) * _stakeMonth) / 100);
        totalreward[msg.sender] = totalRewardGeneratead;
        interestPerSecond = totalRewardGeneratead / (_stakeMonth * secInMonth);
        emit staked(
            stakedAmount,
            StakeTime,
            amount,
            _stakeMonth,
            totalRewardGeneratead,
            interestPerSecond
        );
    }

    function rewardGen() public {
        rewardGeneratedTime = block.timestamp;
        lastRewardTime[msg.sender].push(rewardGeneratedTime);
        totalRewardTime = block.timestamp - StakeTime;
        rewardAvailable = totalRewardTime * interestPerSecond;
        claimableReward[msg.sender] = rewardAvailable;
        claimableReward[msg.sender] =
            rewardAvailable -
            totalRewardedAmount[msg.sender];
        rewardGeneratedFor = claimableReward[msg.sender] / interestPerSecond;
        emit RewardGen(
            totalRewardTime,
            claimableReward[msg.sender],
            rewardGeneratedFor
        );
    }

    function claimReward() public {
        require(claimableReward[msg.sender] > 100, "minimum withdraw is 100");
        totalRewardedAmount[msg.sender] =
            claimableReward[msg.sender] +
            totalRewardedAmount[msg.sender];
        totalreward[msg.sender] -= claimableReward[msg.sender];
        _mint(msg.sender, claimableReward[msg.sender]);
        claimableReward[msg.sender] -= claimableReward[msg.sender];
        emit mintabledAmount(
            claimableReward[msg.sender],
            totalRewardedAmount[msg.sender],
            totalreward[msg.sender]
        );
    }

    function matureAmount() public {
        require(stakedAmount > 0, " must stake some amount");
        require(
            coolingTime + 20 <= block.timestamp,
            "Can only generate after cooling Time"
        );
       // require(amountStakeClaimable <= stakedAmount,"Error: Timeout");
        stakePerWEEK = _stakedMoney[msg.sender] / 20;
        timeAfterStakeFinish = block.timestamp - coolingTime;
        weekOfClaim = timeAfterStakeFinish / 20;
        amountStakeClaimable = weekOfClaim * stakePerWEEK;

        ClaimMature = amountStakeClaimable - totalclaimed[msg.sender];

        emit Withdrawl(
            stakePerWEEK,
            timeAfterStakeFinish,
            weekOfClaim,
            amountStakeClaimable,
            stakedAmount
        );
    }

    function claimPrinciple() public {
        //  require(stakedAmount > 0, " must stake some amount");
        require(ClaimMature > 0, "Must mature amount to claim");
        require(stakePerWEEK <= ClaimMature, "claim only after 20 seconds");
        // require(totalclaimed[msg.sender] <= stakedAmount,"Error: Timeout");
        Rijent.transferPrice(address(this), msg.sender, ClaimMature);
        totalclaimed[msg.sender] = ClaimMature + totalclaimed[msg.sender];

        stakedAmount -= ClaimMature;
        ClaimMature -= ClaimMature;
        emit _Transfer(address(this), msg.sender, ClaimMature);
    }

    function stakemoney(address account) public view returns (uint256) {
        return _stakedMoney[account];
    }

    function totalSupply() public view virtual override returns (uint256) {
        return stakedAmount;
    }

    function ClaimableReward() public view virtual returns (uint256) {
        return claimableReward[msg.sender];
    }

    /////////////////////////   EVENT    ///////////////////////////////

    event RewardGen(
        uint256 claimtime,
        uint256 generatedTime,
        uint256 rewardtime
    );

    event mintabledAmount(
        uint256 amount,
        uint256 totalRewardedAmount,
        uint256 totalreward
    );

    event _Transfer(address indexed from, address indexed to, uint256 value);

    event staked(
        uint256 stakedAmount,
        uint256 StakeTime,
        uint256 amount,
        uint256 _stakeMonth,
        uint256 totalRewardGeneratead,
        uint256 interestPerSecond
    );

    event Withdrawl(
        uint256 stakePerWEEK,
        uint256 timeAfterStakeFinish,
        uint256 weekOfClaim,
        uint256 amountStakeClaimable,
        uint256 stakedAmount
    );
}
