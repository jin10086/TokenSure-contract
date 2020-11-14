pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";


interface Controller {
    function vaults(address) external view returns (address);
    function rewards() external view returns (address);
}

/*

 A strategy must implement the following calls;
 
 - deposit()
 - withdraw(address) must exclude any tokens used in the yield - Controller role - withdraw should return to Controller
 - withdraw(uint) - Controller | Vault role - withdraw should always return to vault
 - withdrawAll() - Controller | Vault role - withdraw should always return to vault
 - balanceOf()
 
 Where possible, strategies must remain as immutable as possible, instead of updating variables, we update the contract by linking it in the controller
 
*/

interface UniswapRouter {
    function swapExactTokensForTokens(uint, uint, address[] calldata, address, uint) external;
}

// https://etherscan.io/tx/0xe5130f9182ab0ee26ba6600b08a6b66b160867ccedfeb4b3aff1bd6f84da1c24
interface IUniHelper {
    function swapAndAddLiquidityTokenAndToken(
        address tokenAddressA,
        address tokenAddressB,
        uint112 amountA,
        uint112 amountB,
        uint112 minLiquidityOut,
        address to,
        uint64 deadline
    ) external returns(uint liquidity);
}

// 
interface IStakingRewards {
    function balanceOf(address account) external view returns (uint256);
    // Mutative
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward() external;
}

contract StrategyUniswap_ETH_USDC_LP {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    
    address constant public want = address(0x1238773Aa48644747aCDBA224732e0C2ecAC09e7); // LP
    address constant public unirouter = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address constant public yfii = address(0xa1d0E215a23d7030842FC67cE582a6aFa3CCaB83);
    address constant public output = address(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984); // UNI   
    address constant public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address constant public usdt = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC
    address constant public miner = address(0x7FBa4B8Dc5E7616e59622806932DBea72537A56b); // Uniswap V2: ETH/USDC UNI Pool    
    address constant public unihelper = address(0x46041Bf02edd6b0CF93bD0db42370CBF4DA67D0b); 



    uint public strategyfee = 100;
    uint public fee = 300;
    uint public burnfee = 500;
    uint public callfee = 100;
    uint constant public max = 1000;

    uint public withdrawalFee = 0;
    uint constant public withdrawalMax = 10000;
    
    address public governance;
    address public controller;
    address public strategyDev;
    address public burnAddress = 0xB6af2DabCEBC7d30E440714A33E5BD45CEEd103a;

    string public getName;

    address[] public swap2YFIIRouting;
    address[] public swap2TokenRouting;

    
    constructor() public {
        governance = tx.origin;
        controller = 0x5c5AFd6d344145F66c28611e6cbFf2100E5bc19e;
        getName = string(
            abi.encodePacked("yfii:Strategy:UNI"));
        swap2TokenRouting = [output,weth];
        swap2YFIIRouting = [weth,yfii];
        // doApprove();
        strategyDev = 0x6465F1250c9fe162602Db83791Fc3Fb202D70a7B; //tx.origin; //TODO:换成 策略提供者的地址
 
    }

    function doApprove () public{
        //卖uni
        IERC20(output).safeApprove(unirouter, 0);
        IERC20(output).safeApprove(unirouter, uint(-1));

        // 卖weth 到yfii
        IERC20(weth).safeApprove(unirouter, 0);
        IERC20(weth).safeApprove(unirouter, uint(-1)); 

        // lp存到挖矿合约  
        IERC20(want).safeApprove(miner, 0);
        IERC20(want).safeApprove(miner, uint(-1));  

        // weth 换 lp
        IERC20(weth).safeApprove(unihelper, 0);
        IERC20(weth).safeApprove(unihelper, uint(-1)); 
        // usdt 换 lp       
        IERC20(usdt).safeApprove(unihelper, 0);
        IERC20(usdt).safeApprove(unihelper, uint(-1));
    }
        
    function deposit() public {
        uint _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            IStakingRewards(miner).stake(_want);            
        }        
    }
    
    // Controller only function for creating additional rewards from dust
    function withdraw(IERC20 _asset) external returns (uint balance) {
        require(msg.sender == controller, "!controller");
        require(want != address(_asset), "want");
        require(output != address(_asset), "uni");
        require(weth != address(_asset), "weth");
        require(usdt != address(_asset), "usdt");
        balance = _asset.balanceOf(address(this));
        _asset.safeTransfer(controller, balance);
    }
    
    // Withdraw partial funds, normally used with a vault withdrawal
    function withdraw(uint _amount) external {
        require(msg.sender == controller, "!controller");
        uint _balance = IERC20(want).balanceOf(address(this));
        if (_balance < _amount) {
            _amount = _withdrawSome(_amount.sub(_balance));
            _amount = _amount.add(_balance);
        }
        
        uint _fee = 0;
        if (withdrawalFee>0){
            _fee = _amount.mul(withdrawalFee).div(withdrawalMax);        
            IERC20(want).safeTransfer(Controller(controller).rewards(), _fee);
        }
        
        address _vault = Controller(controller).vaults(address(want));
        require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
        
        IERC20(want).safeTransfer(_vault, _amount.sub(_fee));
    }
    
    // Withdraw all funds, normally used when migrating strategies
    function withdrawAll() external returns (uint balance) {
        require(msg.sender == controller, "!controller");
        _withdrawAll();
        
        
        balance = IERC20(want).balanceOf(address(this));
        
        address _vault = Controller(controller).vaults(address(want));
        require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
        IERC20(want).safeTransfer(_vault, balance);
    }
    
    function _withdrawAll() internal {
        IStakingRewards(miner).withdraw(balanceOfPool());        
    }
    
    function harvest() public {
        require(!Address.isContract(msg.sender),"!contract");
        IStakingRewards(miner).getReward();
        
        doswap();
        dosplit();
        deposit();
        
    }
    function doswap() internal {
        uint256 _2weth = IERC20(output).balanceOf(address(this)); 
        // Uni -> WETH
        UniswapRouter(unirouter).swapExactTokensForTokens(_2weth, 0, swap2TokenRouting, address(this), now.add(1800));
        // WETH -> YFII 10%
        uint256 _2yfii = IERC20(weth).balanceOf(address(this)).mul(10).div(100);
        UniswapRouter(unirouter).swapExactTokensForTokens(_2yfii, 0, swap2YFIIRouting, address(this), now.add(1800));
        // WETH -> LP
        IUniHelper(unihelper).swapAndAddLiquidityTokenAndToken(weth,usdt,uint112(IERC20(weth).balanceOf(address(this))),uint112(IERC20(usdt).balanceOf(address(this))),0,address(this),uint64(now.add(1800)));            
    }
    function dosplit() internal{
        uint b = IERC20(yfii).balanceOf(address(this));
        uint _fee = b.mul(fee).div(max);
        uint _callfee = b.mul(callfee).div(max);
        uint _burnfee = b.mul(burnfee).div(max);
        IERC20(yfii).safeTransfer(Controller(controller).rewards(), _fee); //4%  3% team +1% insurance
        IERC20(yfii).safeTransfer(msg.sender, _callfee); //call fee 1%
        IERC20(yfii).safeTransfer(burnAddress, _burnfee); //burn fee 5%

        if (strategyfee >0){
            uint _strategyfee = b.mul(strategyfee).div(max);
            IERC20(yfii).safeTransfer(strategyDev, _strategyfee);
        }
    }
    
    function _withdrawSome(uint256 _amount) internal returns (uint) {
        IStakingRewards(miner).withdraw(_amount);        
        return _amount;
    }
    
    function balanceOfWant() public view returns (uint) {
        return IERC20(want).balanceOf(address(this));
    }
    
    function balanceOfPool() public view returns (uint) {
        return IStakingRewards(miner).balanceOf(address(this));
    }
    
    function balanceOf() public view returns (uint) {
        return balanceOfWant();
    }
    
    function setGovernance(address _governance) external {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }
    
    function setController(address _controller) external {
        require(msg.sender == governance, "!governance");
        controller = _controller;
    }
    function setFee(uint256 _fee) external{
        require(msg.sender == governance, "!governance");
        fee = _fee;
    }
    function setStrategyFee(uint256 _fee) external{
        require(msg.sender == governance, "!governance");
        strategyfee = _fee;
    }
    function setCallFee(uint256 _fee) external{
        require(msg.sender == governance, "!governance");
        callfee = _fee;
    }
    function setBurnFee(uint256 _fee) external{
        require(msg.sender == governance, "!governance");
        burnfee = _fee;
    }
    function setBurnAddress(address _burnAddress) public{
        require(msg.sender == governance, "!governance");
        burnAddress = _burnAddress;
    }

    function setWithdrawalFee(uint _withdrawalFee) external {
        require(msg.sender == governance, "!governance");
        require(_withdrawalFee <=100,"fee >= 1%"); //max:1%
        withdrawalFee = _withdrawalFee;
    }
}