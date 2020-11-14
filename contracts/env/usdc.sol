pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDC is ERC20{

    constructor () public ERC20("USDC","USDC"){
        _mint(msg.sender,10000*1e18);
    }

    function faucet() public{
        _mint(msg.sender,1000*1e18);
    }
}

