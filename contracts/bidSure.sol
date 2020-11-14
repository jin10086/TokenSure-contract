pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract bidSure is ERC721,ERC721Burnable,Ownable {
    
    struct BID{
        uint256 apy;
        address margin; //保证金代币地址
        uint256 marginAmount; //保证金数量
        uint256 starttime;
        uint256 minimumPeriodOfGuarantee;//最少保期时间,秒为单位
    }
    mapping (uint256 => BID) public bids;

    constructor() public ERC721("bidSure", "bSure") {
    }
    
    function mint(address player, uint256 newItemId,BID memory _info) public onlyOwner {
        _mint(player, newItemId);
        _setSureinfo(newItemId,_info);
    }

    function burnWithContract(uint256 tokenId) public onlyOwner {
        _burn(tokenId);
    }
    
    function _setSureinfo(uint256 tokenId,BID memory _info) internal{
        bids[tokenId] = _info;
    }
}