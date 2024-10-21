// Solidity 0.8.21, which includes built-in overflow and underflow checks, making the SafeMath library unnecessary.
// Changes Made
// 1 Updated Solidity Version: Changed the pragma statement to ^0.8.21.
// 2 Removed SafeMath: Solidity 0.8.x includes built-in overflow and underflow checks.
// 3 Simplified Arithmetic: Directly used arithmetic operations without SafeMath.
// 4 Constructor Syntax: Updated the constructor syntax to the latest version.
// 5 Payable Admin: Ensured the admin address is payable for withdrawals.
// This version maintains the same functionality while leveraging the latest Solidity features for cleaner and safer code.


// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

interface IST20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract Sale_Contract is Ownable {
    IST20 public token;
    uint256 public rate;
    uint256 public weiRaised;
    uint256 public weiMaxPurchaseBnb;
    address payable private admin;
    mapping(address => uint256) public purchasedBnb;

    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    constructor(uint256 _rate, IST20 _token, uint256 _max) {
        require(_rate > 0, "Rate must be greater than 0");
        require(_max > 0, "Max purchase must be greater than 0");
        require(address(_token) != address(0), "Invalid token address");

        rate = _rate;
        token = _token;
        weiMaxPurchaseBnb = _max;
        admin = payable(msg.sender);
    }

    fallback() external payable {
        revert();
    }

    receive() external payable {
        revert();
    }

    function buyTokens(address _beneficiary) public payable {
        uint256 maxBnbAmount = maxBnb(_beneficiary);
        uint256 weiAmount = msg.value > maxBnbAmount ? maxBnbAmount : msg.value;
        weiAmount = _preValidatePurchase(_beneficiary, weiAmount);
        uint256 tokens = _getTokenAmount(weiAmount);
        weiRaised += weiAmount;
        _processPurchase(_beneficiary, tokens);
        emit TokenPurchase(msg.sender, _beneficiary, weiAmount, tokens);
        _updatePurchasingState(_beneficiary, weiAmount);

        if (msg.value > weiAmount) {
            uint256 refundAmount = msg.value - weiAmount;
            payable(msg.sender).transfer(refundAmount);
        }
    }

    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) public view returns (uint256) {
        require(_beneficiary != address(0), "Beneficiary address cannot be zero");
        require(_weiAmount != 0, "Wei amount cannot be zero");

        uint256 tokenAmount = _getTokenAmount(_weiAmount);
        uint256 curBalance = token.balanceOf(address(this));
        if (tokenAmount > curBalance) {
            return (curBalance * 1e18) / rate;
        }
        return _weiAmount;
    }

    function _deliverTokens(address _beneficiary, uint256 _tokenAmount) internal {
        token.transfer(_beneficiary, _tokenAmount);
    }

    function _processPurchase(address _beneficiary, uint256 _tokenAmount) internal {
        _deliverTokens(_beneficiary, _tokenAmount);
    }

    function _updatePurchasingState(address _beneficiary, uint256 _weiAmount) internal {
        purchasedBnb[_beneficiary] += _weiAmount;
    }

    function _getTokenAmount(uint256 _weiAmount) public view returns (uint256) {
        return (_weiAmount * rate) / 1e18;
    }

    function setPresaleRate(uint256 _rate) external {
        require(admin == msg.sender, "Caller is not the owner");
        rate = _rate;
    }

    function maxBnb(address _beneficiary) public view returns (uint256) {
        return weiMaxPurchaseBnb - purchasedBnb[_beneficiary];
    }

    function withdrawCoins() external {
        require(admin == msg.sender, "Caller is not the owner");
        admin.transfer(address(this).balance);
    }

    function withdrawTokens(address tokenAddress, uint256 tokens) external {
        require(admin == msg.sender, "Caller is not the owner");
        IST20(tokenAddress).transfer(admin, tokens);
    }
}
