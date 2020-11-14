pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


interface YVault{
    function getPricePerFullShare() external view returns (uint);
    function depositToken0(uint _amount) external; 
    function depositToken1(uint _amount) external; 
    function withdrawToken0(uint _shares) external;
    function withdrawToken1(uint _shares) external;
    function token() external view returns(address);
}


interface IUniswapV2Pair {

  function totalSupply() external view returns (uint);
  function balanceOf(address owner) external view returns (uint);


  function token0() external view returns (address);
  function token1() external view returns (address);
  function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface  ITOKEN{

    //返回底层金本位资产数量(USD)
    function getUnderling(address,uint256) external view returns(uint256);
    function ilp2usd(address,address,uint256) external returns (uint256); //ilp 2 usd
    function usd2ilp(address,address,uint256) external returns (uint256);// usd 2 ilp
 }

contract yfiicover is ITOKEN{
    
    address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant usdc = address(0xd76bb6fdd24aA5f85ef614Ab3008190cB279953F);

    using SafeMath for uint256;

    
    function getUnderling(address _lp,uint256 _amount) override public view returns(uint256){
        
        uint256 liquidity = YVault(_lp).getPricePerFullShare().mul(_amount).div(1e18); 
        address lptoken = YVault(_lp).token();
        (uint112 _reserve0, uint112 _reserve1,) = IUniswapV2Pair(lptoken).getReserves(); // gas savings
        address _token0 = IUniswapV2Pair(lptoken).token0();                                // gas savings
        address _token1 = IUniswapV2Pair(lptoken).token1();                                // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(lptoken));
        uint balance1 = IERC20(_token1).balanceOf(address(lptoken));

        uint _totalSupply = IUniswapV2Pair(lptoken).totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        uint amount0;
        uint amount1;
        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        
        if(_token0 == weth){
            return getAmountOut(amount0,_reserve0,_reserve1).add(amount1);
        }else{
            return getAmountOut(amount1,_reserve1,_reserve0).add(amount1);
        }
        
    }
    
    function ilp2usd(address _token,address _lp,uint256 _amount) override external returns (uint256){
        
        require(_token == usdc,"!");//TODO:后面加个其他代币转到USDC的转换器.        
        uint256 beforeBalance = IERC20(_token).balanceOf(address(this));
        if (_token < weth){
            YVault(_lp).withdrawToken1(_amount);
        }else{
            YVault(_lp).withdrawToken0(_amount);
        }
        uint256 afterBalance = IERC20(usdc).balanceOf(address(this));
        uint256 balance = afterBalance-beforeBalance;
        IERC20(usdc).transfer(msg.sender,balance);
        return balance;
        
    }
    
    function usd2ilp(address _token,address _lp,uint256 _amount) override external returns (uint256){
        require(_token == usdc,"!");//TODO:后面加个其他代币转到USDC的转换器.        

        uint256 beforeBalance = IERC20(_lp).balanceOf(address(this));
        IERC20(_token).approve(_lp,_amount);
        if (_token < weth){
            YVault(_lp).depositToken1(_amount);
        }else{
            YVault(_lp).depositToken0(_amount);
        }
        uint256 afterBalance = IERC20(_lp).balanceOf(address(this));
        uint256 balance = afterBalance-beforeBalance;
        IERC20(_lp).transfer(msg.sender,balance);
        return balance;
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

 }





