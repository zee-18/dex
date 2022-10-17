// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./IERC20.sol";

contract AMM {
    IERC20 public immutable token0;
    IERC20 public immutable token1;

    //How much token0 and token1 are in the contract i.e. reserves of token1 and token2
    uint public reserve0;
    uint public reserve1;

    //when user provide liquidity we need to mint or burn shares
    //total supply by liquidity providers
    uint public totalSupply;
    // will hold share/balance of each user/liquidity provider against its address
    mapping(address => uint) public balanceOf;

    constructor(address _token0, address _token1) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    //function for mint shares
    function _mint(address _to, uint _amount) private {
        balanceOf[_to] += _amount;
        totalSupply += _amount;
    }

    //funtion for burn shares
    function _burn(address _from, uint _amount) private {
        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
    }

    // will update the reserves
    function _updateReserve(uint _reserve0, uint _reserve1) private {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    //aggreagator for usdt

    // // external functions users can call from outside of contract

    // swap function is for swaping from token0 to token1 OR token1 to token0
    // user will provide address of token to determine which token he wants to swap and its amount
    function swap(address _tokenIn, uint _amountIn) 
        external returns (uint amountOut) 
    {
        // checking if tokenIn is either token0 or token1
        // and amountIn is greater than 0
        require(_tokenIn == address(token0) || _tokenIn == address(token1), 'Invalid Token');
        require(_amountIn > 0, 'Invalid amount');

        // Pull in tokenIn into pur reserves/pool
        // Determine whether tokenIn is token0 or token1
        bool isToken0 = _tokenIn == address(token0);
        // declaring local variables 
        (IERC20 tokenIn, IERC20 tokenOut, uint reserveIn, uint reserveOut) = isToken0
                                                                            ? (token0, token1, reserve0, reserve1) 
                                                                            : (token1, token0, reserve1, reserve0);

        // msg.sender will be the user who wants to swap using the contract
        // address(this) => address of this contract
        tokenIn.transferFrom(msg.sender, address(this), _amountIn);

        // Calculate token out (including fees), fee 0.3%
        // y dx / (x + dx) = dy
        // where dy => amount of tokenOut which is to be determined for swap
        //       y => is the amount of total token out which is locked in this contract
        //       token out means => token which is going/swaping out
        //       x => is the amount of total token in which is locked in this contract
        //       dx =>  amount of tokenIn which is coming in for swap

        // re-calculate amountIn again with fee included means we will deduct 0.3 fee from amountIn
        // in solidity we cant use decimal so,
        uint amountInWithFee = (_amountIn * 997) / 1000;
        // dy = ydx / (x + dx) 
        amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);
        // Transfer token out to msg.sender
        // we've already declared the amountOut in the function definition
        tokenOut.transfer(msg.sender, amountOut);
        // Update the reserves
        // we're keeping track of total token0 and token1 in our contract so no can manipulate
        // and change the reserve amount
        _updateReserve(token0.balanceOf(address(this)), token1.balanceOf(address(this)));

    }

    // users provide both tokens as liquidity in our pool and earn fees they are called liquidity providers

    // 1) token address, token amount
    function addLiquidity(uint _amountToken0, uint _amountToken1) external returns (uint shares) {
        // Pull in token0 and token1
        token0.transferFrom(msg.sender, address(this), _amountToken0);
        token1.transferFrom(msg.sender, address(this), _amountToken1);

        // we're maintaining a ratio that how much user can add liquidity
        // amount 0f token0 / token1 should be equal to amount of reserve0 / reserve1
        // but above rule will apply when there will be reserves more than 0
        if (reserve0 > 0 || reserve1 > 0) {
            require(_amountToken0 * reserve0 == _amountToken1 * reserve1, 'ratio is not equal');
        }
        

        // Mint shares  --> for the LP for adding liquidity in your pool
            // isauthorize minter
        // totalsupply is toal shares of a particular user we are maintaing it on their address
        if (totalSupply == 0) {
            shares = _sqrt(_amountToken0 * _amountToken1);
        } else {
            // shares => dx * totalshares / X => dy * totalshares / Y
            // we're choosing which is minimum 
            shares = _min(
                (_amountToken0 * totalSupply) / reserve0,
                (_amountToken1 * totalSupply) / reserve1
            );
        }
        require(shares > 0, "shares = 0");
        _mint(msg.sender, shares);

        // Update reserves
        // updating the total value of token0 and token1 in this contract
        // that how much token0 and token1 we have in this contract so far
        _updateReserve(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
    }

    // once user add liquidity and have shares they can call remove liquidity method
    // and withdraw their tokens  
    // burning shares
    function removeLiquidity(uint _shares) external returns (uint amount0, uint amount1) {

        // Calculate amount0 and amount1 to withdraw i.e. which we have to return to provider
        uint bal0 = token0.balanceOf(address(this));
        uint bal1 = token1.balanceOf(address(this));

        amount0 = (_shares * bal0) / totalSupply;
        amount1 = (_shares * bal1) / totalSupply;
        require(amount0 > 0 && amount1 > 0, 'amount0 or amount1 = 0');
        // Burn shares => the one we gave to user for providing liquidity
        _burn(msg.sender, _shares);
        // Update reserves 
        _updateReserve(bal0 - amount0, bal1 - amount1);

        // Transfer tokens to mgs.sender
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);
    }

    function _sqrt(uint y) private pure returns (uint z) {
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

    // for returing the minimum value of the two inputs
    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }

}