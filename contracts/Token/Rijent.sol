// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;
import "./BEP20.sol";
import "../utils/Ownable.sol";
import "../utils/SafeMath.sol";

contract Rijent is BEP20, Ownable{
    using SafeMath for uint256;
    uint256 private totalTokens;

    constructor() BEP20("Rijent Coin", "RTC", 9) {
        totalTokens = 290000000 * 10**uint256(decimals());
        _mint(msg.sender, totalTokens);
    }

    function transfer(address _receiver, uint256 _amount)
        public
        virtual
        override
        returns (bool success)
    {
        require(_receiver != address(0));

        return BEP20.transfer(_receiver, _amount);
    }

    function getBurnedAmountTotal() public view returns (uint256 _amount) {
        return totalTokens.sub(totalSupply());
    }

    function burn(uint256 _amount) public {
        _burn(msg.sender, _amount);
    }

    //     constructor() BEP20("Rijent", "Rpay") {}

    function mint(address account, uint256 amount) public onlyOwner(){
        _mint(account, amount);
    }

    function transferPrice(
        address sender,
        address receiver,
        uint256 amount
    ) public {
        BEP20._transfer(sender, receiver, amount);
    }
}
