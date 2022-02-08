//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./utils/SafeMath.sol";
import "./security/ReentrancyGuard.sol";
import "./Token/Rijent.sol";
import "./utils/Ownable.sol";
import "./utils/RewardDistributionReceipt.sol";

// RewardsDistributionRecipient,
// Pausable,
contract StakingReward is
    ReentrancyGuard,
    Rijent,
    //  Ownable,
    RewardsDistributionRecipient
{
    using SafeMath for uint256;

    /*-----------STATE VARIABLES--------------*/

    IBEP20 public StakingToken;
    //only fpr testing (100 * (1E9))
    uint256 MIN_DEPOSIT = 100;
    uint256 MIN_WITHDRAWAL = 100;
    uint256 private secondsInOneMonth = 30 * 24 * 60 * 60;
    uint256 public rewardGenerateTime;
    uint256 public _totalReward;
    uint256 public _rewardPerSecond;
    uint256 private _stakeAmount;
    uint256 private _capitalPerWeek;
    uint256 private coolingPeriod;
    uint256 private amountforWeeks;

    uint256 private _totalsupply;

    mapping(address => uint256) public claimableReward;
    mapping(address => uint256) public totalRewardGenerateFor;
    mapping(address => uint256) public userStakedAmount;
    mapping(address => uint256[]) public lastRewardTime;
    mapping(address => uint256) public stakingTime;
    mapping(address => uint256) public ClaimedTime;

    /*-----------CONSTRUCTOR--------------*/

    constructor(address _RijentToken) {
        StakingToken = IBEP20(_RijentToken);
    }

    /*-----------VIEWS FUNCTION------------*/

    function totalsupply() public view returns (uint256) {
        return _totalsupply;
    }

    function unfreezedCapital() public {
        _stakeAmount = userStakedAmount[msg.sender];
        require(_stakeAmount > 0, "No Stake Amount Found");
        _capitalPerWeek = _stakeAmount.div(20);
        emit unfreezedCapitalAmount(msg.sender, _stakeAmount, _capitalPerWeek);
    }

    /*-----------MUTATIVE FUNCTION------------*/

    //stake amount must be equal to or greater tghen 1 ether i.e; 1e18
    function stake(uint256 amount, uint256 months) public {
        require(
            months == 12 || months == 24 || months == 36 || months == 60,
            "Not Appropriate Plan"
        );
        require(amount >= MIN_DEPOSIT, "Insufficient Balance");
        //for how much time we stake our amount
        coolingPeriod = months.mul(secondsInOneMonth);
        _totalsupply = _totalsupply.add(amount);
        stakingTime[msg.sender] = block.timestamp;
        totalRewardGenerateFor[msg.sender] = coolingPeriod;
        Rijent.transferPrice(msg.sender, address(this), amount);
        userStakedAmount[msg.sender] = amount;
        emit staked(
            msg.sender,
            address(this),
            stakingTime[msg.sender],
            amount,
            coolingPeriod
        );
    }

    function rewardGeneration(
        uint256 percentRate,
        uint256 months
    ) public {
        
            require(
                (percentRate == 3 && months == 12) ||
                    (percentRate == 4 && months == 24) ||
                    (percentRate == 5 && months == 36) ||
                    (percentRate == 6 && months == 60),
                "Not in plan"
            );

            require(
                claimableReward[msg.sender] <= _totalReward,
                "Insufficient Reward Found"
            );

            uint256 totalRewardInPercentage = percentRate.mul(months);
            _totalReward = (
                userStakedAmount[msg.sender].mul(totalRewardInPercentage).div(
                    100
                )
            );
            // can change totalRewardGenerate to userStakedAmount
            totalRewardGenerateFor[msg.sender] = _totalReward;
            // uint256 totalTime = months * secondsInOneMonth;
            _rewardPerSecond = (_totalReward.div(coolingPeriod));
            if (ClaimedTime[msg.sender] == 0) {
            rewardGenerateTime = block.timestamp - stakingTime[msg.sender];
            claimableReward[msg.sender] = _rewardPerSecond.mul(
                rewardGenerateTime
            );
        } else {
            rewardGenerateTime = block.timestamp - ClaimedTime[msg.sender];
            claimableReward[msg.sender] = _rewardPerSecond.mul(
                rewardGenerateTime
            );
        }
        emit rewardGenerated(
            msg.sender,
            _totalReward,
            _rewardPerSecond,
            rewardGenerateTime
        );
    }

    function claim(uint256 amount) public {
        require(_capitalPerWeek <= userStakedAmount[msg.sender],"NO funds found");
         ClaimedTime[msg.sender] = block.timestamp;
        if (_totalReward > 0) {
            require(amount > MIN_WITHDRAWAL, "out of limit");
            require(amount <= _totalReward, "No reward left");
            // ClaimedTime[msg.sender] = block.timestamp;
            _totalReward = _totalReward.sub(amount);
            claimableReward[msg.sender] = claimableReward[msg.sender].sub(
                amount
            );
            Rijent.mint(msg.sender, amount);
        } else if (_totalReward == 0) {
            require(
                coolingPeriod < block.timestamp,
                "Can Claim Capital After Cooling period"
            );
           
            Rijent.transferPrice(address(this), msg.sender, _capitalPerWeek);
        } else {
            uint256 lastClaimedTime = block.timestamp.sub(
                ClaimedTime[msg.sender]
            );
            uint256 numberOfWeeks = lastClaimedTime.div(604800);
            require(
                lastClaimedTime == ClaimedTime[msg.sender].add(90),
                "can claim only after 7 days"
            );

            amountforWeeks = _capitalPerWeek.mul(numberOfWeeks);
            
            Rijent.transferPrice(address(this), msg.sender, amountforWeeks);
        }
        emit claimedReward(
            msg.sender,
            amount,
            _totalReward,
            _rewardPerSecond,
            amountforWeeks
        );
    }

    // function exit() external {
    //     claim(userStakedAmount[msg.sender]);
    // }

    /*-----------EVENTS------------*/
    event staked(
        address sender,
        address receiver,
        uint256 lastUpdatedTime,
        uint256 amount,
        uint256 coolingPeriod
    );
    event claimedReward(
        address receiver,
        uint256 amount,
        uint256 _totalReward,
        uint256 _claimableReward,
        uint256 amountforWeeks
    );
    event rewardDurationUpdated(uint256 newRewardDuration);
    event rewardPaid(address receiver, uint256 amount);
    event RewardAdded(uint256 reward);
    event Recovered(address token, uint256 amount);
    event rewardGenerated(
        address receiver,
        uint256 _totalReward,
        uint256 _claimableReward,
        uint256 rewardGenerateTime
    );
    event unfreezedCapitalAmount(
        address userAddress,
        uint256 stakeAmount,
        uint256 capitalPerWeek
    );
}
