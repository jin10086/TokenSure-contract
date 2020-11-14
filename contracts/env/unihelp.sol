pragma solidity ^0.6.2;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";




// Dependency file: @uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol

// pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}


// Dependency file: contracts/libraries2/UniswapV2Library.sol

// pragma solidity >=0.5.0;

library UniswapV2Library {
    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            ))));
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }
}


// Dependency file: contracts/libraries2/Math.sol

// pragma solidity >=0.5.0;

// a library for performing various math operations

library Math {
    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint y) internal pure returns (uint z) {
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
}


// Dependency file: contracts/interfaces/IUniswapV2Router01.sol

// pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}


// Dependency file: contracts/interfaces/IUniswapV2Router02.sol

// pragma solidity >=0.6.2;

// import 'contracts/interfaces/IUniswapV2Router01.sol';

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}


// Dependency file: contracts/interfaces/IWETH.sol

// pragma solidity >=0.5.0;

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}


// Root file: contracts/UniswapV2AddLiquidityHelperV1.sol

//SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/math/SafeMath.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
// To avoid SafeMath being // imported twice, we modified UniswapV2Library.sol.
// import "contracts/libraries2/UniswapV2Library.sol";
// We modified the pragma.
// import "contracts/libraries2/Math.sol";
// import "contracts/interfaces/IUniswapV2Router02.sol";
// import "contracts/interfaces/IWETH.sol";

/// @author Roger Wu (Twitter: @rogerwutw, GitHub: Roger-Wu)
contract UniswapV2AddLiquidityHelperV1 is Ownable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    address public _uniswapV2FactoryAddress; // 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
    address public _uniswapV2Router02Address; // 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    address public _wethAddress; // 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2

    constructor(
        address uniswapV2FactoryAddress,
        address uniswapV2Router02Address,
        address wethAddress
    ) public {
        _uniswapV2FactoryAddress = uniswapV2FactoryAddress;
        _uniswapV2Router02Address = uniswapV2Router02Address;
        _wethAddress = wethAddress;
    }

    // fallback() external payable {}
    receive() external payable {}

    // Add as more tokenA and tokenB as possible to a Uniswap pair.
    // The ratio between tokenA and tokenB can be any.
    // Approve enough amount of tokenA and tokenB to this contract before calling this function.
    // Uniswap pair tokenA-tokenB must exist.
    // gas cost: ~320000
    function swapAndAddLiquidityTokenAndToken(
        address tokenAddressA,
        address tokenAddressB,
        uint112 amountA,
        uint112 amountB,
        uint112 minLiquidityOut,
        address to,
        uint64 deadline
    ) public returns(uint liquidity) {
        require(deadline >= block.timestamp, 'EXPIRED');
        require(amountA > 0 || amountB > 0, "amounts can not be both 0");
        // limited by Uniswap V2

        // transfer user's tokens to this contract
        if (amountA > 0) {
            _receiveToken(tokenAddressA, amountA);
        }
        if (amountB > 0) {
            _receiveToken(tokenAddressB, amountB);
        }

        return _swapAndAddLiquidity(
            tokenAddressA,
            tokenAddressB,
            uint(amountA),
            uint(amountB),
            uint(minLiquidityOut),
            to
        );
    }

    // Add as more ether and tokenB as possible to a Uniswap pair.
    // The ratio between ether and tokenB can be any.
    // Approve enough amount of tokenB to this contract before calling this function.
    // Uniswap pair WETH-tokenB must exist.
    // gas cost: ~320000
    function swapAndAddLiquidityEthAndToken(
        address tokenAddressB,
        uint112 amountB,
        uint112 minLiquidityOut,
        address to,
        uint64 deadline
    ) public payable returns(uint liquidity) {
        require(deadline >= block.timestamp, 'EXPIRED');

        uint amountA = msg.value;
        address tokenAddressA = _wethAddress;

        require(amountA > 0 || amountB > 0, "amounts can not be both 0");
        // require(amountA < 2**112, "amount of ETH must be < 2**112");

        // convert ETH to WETH
        IWETH(_wethAddress).deposit{value: amountA}();
        // transfer user's tokenB to this contract
        if (amountB > 0) {
            _receiveToken(tokenAddressB, amountB);
        }

        return _swapAndAddLiquidity(
            tokenAddressA,
            tokenAddressB,
            amountA,
            uint(amountB),
            uint(minLiquidityOut),
            to
        );
    }

    // add as more tokens as possible to a Uniswap pair
    function _swapAndAddLiquidity(
        address tokenAddressA,
        address tokenAddressB,
        uint amountA,
        uint amountB,
        uint minLiquidityOut,
        address to
    ) internal returns(uint liquidity) {
        (uint amountAToAdd, uint amountBToAdd) = _swapToSyncRatio(
            tokenAddressA,
            tokenAddressB,
            amountA,
            amountB
        );

        _approveTokenToRouterIfNecessary(tokenAddressA, amountAToAdd);
        _approveTokenToRouterIfNecessary(tokenAddressB, amountBToAdd);
        (, , liquidity) = IUniswapV2Router02(_uniswapV2Router02Address).addLiquidity(
            tokenAddressA, // address tokenA,
            tokenAddressB, // address tokenB,
            amountAToAdd, // uint amountADesired,
            amountBToAdd, // uint amountBDesired,
            1, // uint amountAMin,
            1, // uint amountBMin,
            to, // address to,
            2**256-1 // uint deadline
        );

        require(liquidity >= minLiquidityOut, "minted liquidity not enough");
        
        uint _tokenABalance = IERC20(tokenAddressA).balanceOf(address(this));
        uint _tokenBBalance = IERC20(tokenAddressB).balanceOf(address(this));
        if (_tokenABalance >0){
            IERC20(tokenAddressA).safeTransfer(tx.origin,_tokenABalance);
        }
        if (_tokenBBalance >0){
            IERC20(tokenAddressB).safeTransfer(tx.origin,_tokenBBalance);
        }
        

        // There may be a small amount of tokens left in this contract.
        // Usually it doesn't worth it to spend more gas to transfer them out.
        // These tokens will be considered as a donation to the owner.
        // All ether and tokens directly sent to this contract will be considered as a donation to the contract owner.
    }

    // swap tokens to make newAmountA / newAmountB ~= newReserveA / newReserveB
    function _swapToSyncRatio(
        address tokenAddressA,
        address tokenAddressB,
        uint amountA,
        uint amountB
    ) internal returns(
        uint newAmountA,
        uint newAmountB
    ) {
        (uint reserveA, uint reserveB) = UniswapV2Library.getReserves(_uniswapV2FactoryAddress, tokenAddressA, tokenAddressB);

        bool isSwitched = false;
        // swap A and B s.t. amountA * reserveB >= reserveA * amountB
        if (amountA * reserveB < reserveA * amountB) {
            (tokenAddressA, tokenAddressB) = (tokenAddressB, tokenAddressA);
            (reserveA, reserveB) = (reserveB, reserveA);
            (amountA, amountB) = (amountB, amountA);
            isSwitched = true;
        }

        uint amountAToSwap = calcAmountAToSwap(reserveA, reserveB, amountA, amountB);
        require(amountAToSwap <= amountA, "bugs in calcAmountAToSwap cause amountAToSwap > amountA");
        if (amountAToSwap > 0) {
            address[] memory path = new address[](2);
            path[0] = tokenAddressA;
            path[1] = tokenAddressB;

            _approveTokenToRouterIfNecessary(tokenAddressA, amountAToSwap);
            uint[] memory swapOutAmounts = IUniswapV2Router02(_uniswapV2Router02Address).swapExactTokensForTokens(
                amountAToSwap, // uint amountIn,
                1, // uint amountOutMin,
                path, // address[] calldata path,
                address(this), // address to,
                2**256-1 // uint deadline
            );

            amountA -= amountAToSwap;
            amountB += swapOutAmounts[swapOutAmounts.length - 1];
        }

        return isSwitched ? (amountB, amountA) : (amountA, amountB);
    }

    function calcAmountAToSwap(
        uint reserveA,
        uint reserveB,
        uint amountA,
        uint amountB
    ) public pure returns(
        uint amountAToSwap
    ) {
        require(reserveA > 0 && reserveB > 0, "reserves can't be empty");
        require(reserveA < 2**112 && reserveB < 2**112, "reserves must be < 2**112");
        require(amountA < 2**112 && amountB < 2**112, "amounts must be < 2**112");
        require(amountA * reserveB >= reserveA * amountB, "require amountA / amountB >= reserveA / reserveB");

        // Let A = reserveA, B = reserveB, C = amountA, D = amountB
        // Let x = amountAToSwap, y = amountBSwapOut
        // We are solving:
        //   (C - x) / (D + y) = (A + C) / (B + D)
        //   (A + 0.997 * x) * (B - y) = A * B
        // Use WolframAlpha to solve:
        //    solve (C - x) * (B + D) = (A + C) * (D + y), (1000 * A + 997 * x) * (B - y) = 1000 * A * B
        // we will get
        //    x = (sqrt(A) sqrt(3988009 A B + 9 A D + 3988000 B C)) / (1994 sqrt(B + D)) - (1997 A) / 1994
        // which is also
        //    x = ((sqrt(A) sqrt(3988009 A B + 9 A D + 3988000 B C)) / sqrt(B + D) - (1997 A)) / 1994

        // A (3988009 B + 9 D) + 3988000 B C
        // = reserveA * (3988009 * reserveB + 9 * amountB) + 3988000 * reserveB * amountA
        // < 2^112 * (2^22 * 2^112 + 2^4 * 2^112) + 2^22 * 2^112 * 2^112
        // < 2^247 + 2^246
        // < 2^248
        // so we don't need SafeMath
        return amountA.div(2);
        // return ((
        //     Math.sqrt(reserveA)
        //     * Math.sqrt(reserveA * (3988009 * reserveB + 9 * amountB) + 3988000 * reserveB * amountA)
        //     / Math.sqrt(reserveB + amountB)
        // ).sub(1997 * reserveA)) / 1994;
    }

    function _receiveToken(address tokenAddress, uint amount) internal {
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
    }

    function _approveTokenToRouterIfNecessary(address tokenAddress, uint amount) internal {
        uint currentAllowance = IERC20(tokenAddress).allowance(address(this), _uniswapV2Router02Address);
        if (currentAllowance < amount) {
            IERC20(tokenAddress).safeIncreaseAllowance(_uniswapV2Router02Address, 2**256 - 1 - currentAllowance);
        }
    }

    function emergencyWithdrawEther() public onlyOwner {
        (msg.sender).transfer(address(this).balance);
    }

    function emergencyWithdrawErc20(address tokenAddress) public onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }
}