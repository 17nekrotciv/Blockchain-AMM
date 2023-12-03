// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC20.sol";

contract AMM{
    IERC20 public immutable joCoin0;
    IERC20 public immutable joCoin1;

    uint public reserve0;
    uint public reserve1;

    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint256)) public liquidity;

    constructor(address joCoin0_, address joCoin1_){
        joCoin0 = IERC20(joCoin0_);
        joCoin1 = IERC20(joCoin1_);
    }

    function update_(uint reserve0_, uint reserve1_) private {
        reserve0 = reserve0_;
        reserve1 = reserve1_;
    }

    function mint_(address to_, uint num_) private{
        balanceOf[to_] += num_;
        totalSupply += num_;
    }

    function burn_(address to_, uint num_) private{
        balanceOf[to_] -= num_;
        totalSupply -= num_;
    }

    function swap(address tokenIn_, uint numIn_) external returns (uint numOut_){
        require(tokenIn_ == address(joCoin0)|| tokenIn_ == address(joCoin1), "Token Invalido");
        require(numIn_ > 0, "Quantidade invalida");
       
        bool isjoCoin0 = tokenIn_ == address(joCoin0);
        (IERC20 tokenIn, IERC20 tokenOut, uint reserveIn, uint reserveOut) = isjoCoin0 
        ? (joCoin0, joCoin1, reserve0, reserve1) 
        : (joCoin1, joCoin0,reserve1, reserve0);

        tokenIn.transferFrom(msg.sender, address(this), numIn_);

        //taxa de 0.5%
        //x^2*y^2 = k
        //y^2dx/(x^2+dx) = dy 
        uint numInWithFee = (numIn_ * 995) / 1000;
        numOut_ = ((reserveOut*reserveOut) * numInWithFee) / ((reserveIn * reserveIn) * numInWithFee);

        tokenOut.transfer(msg.sender, numOut_);

        update_(
            joCoin0.balanceOf(address(this)),
            joCoin1.balanceOf(address(this))
        );
    }

    function addLiquidity(uint num0_, uint num1_) external returns (uint shares){
        require(reserve0 * num0_ == reserve1 * num1_, "dy/dx != y/x");
        joCoin0.transferFrom(msg.sender, address(this), num0_);
        joCoin1.transferFrom(msg.sender, address(this), num1_);
        
        // dy/dx = y/x
        if(totalSupply == 0){
            shares = sqrt_(num0_ * num1_);
        }else{
            shares = min_(
                (num0_ * totalSupply) / reserve0,
                (num1_ * totalSupply) / reserve1
                );
        }
        require(shares > 0, "shares = 0");
        mint_(msg.sender, shares);

        update_(joCoin0.balanceOf(address(this)), joCoin1.balanceOf(address(this)));
    }

    function removeLiquidity(uint shares_) external returns (uint num1, uint num0){
        uint bal0 = joCoin0.balanceOf(address(this));
        uint bal1 = joCoin1.balanceOf(address(this));

        num0 = (shares_ * bal0) / totalSupply;
        num1 = (shares_ * bal1) / totalSupply;
        require(num0 > 0 && num1 > 0, "num0 or num1 = 0");

        burn_(msg.sender, shares_);
        update_(bal0 - num0, bal1 - num1);

        joCoin0.transfer(msg.sender, num0);
        joCoin1.transfer(msg.sender, num1);
    }

    function sqrt_(uint y) private pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min_(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }
}