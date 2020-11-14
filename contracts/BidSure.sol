pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BidSure is ERC721,ERC721Burnable,Ownable {
    
    struct BID{
        uint256 apy;
        // address margin; //保证金代币地址
        uint256 marginAmount; //保证金数量
        uint256 starttime;
        uint256 minimumPeriodOfGuarantee;//最少保期时间,秒为单位
    }
    mapping (uint256 => BID) private _bids;
    constructor() public ERC721("bidSure", "bSure") {
    }
    
    function mint(address player, uint256 newItemId,BID memory _info) public onlyOwner {
        _mint(player, newItemId);
        _setSureinfo(newItemId,_info);
    }
    function update_marginAmount(uint256 tokenId,uint256 _marginAmount)public onlyOwner {
        BID storage _bid = _bids[tokenId];
        _bid.marginAmount = _marginAmount;
    }


    function burnWithContract(uint256 tokenId) public onlyOwner {
        _burn(tokenId);
    }
    
    function _setSureinfo(uint256 tokenId,BID memory _info) internal{
        _bids[tokenId] = _info;
    }

    function bids(uint256 _id) public view returns(BID memory _bid,address _owner){
        _bid = _bids[_id];
        _owner = ownerOf(_id);
    }
}