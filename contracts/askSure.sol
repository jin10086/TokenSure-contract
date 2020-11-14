pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract askSure is ERC721,ERC721Burnable,Ownable {
    
    struct ASK{
        uint256 lpAmount;
        uint256 apy;
        address lpAddress;
        address [] _tokens;
        uint256 [] _amounts;
        uint256 starttime;
        uint256 minimumPeriodOfGuarantee;//最少保期时间,秒为单位
    }
    mapping (uint256 => ASK) private asks;

    constructor() public ERC721("askSure", "aSure") {
    }
    
    function mint(address player, uint256 newItemId,ASK memory _info) public onlyOwner {
        require (_info._tokens.length == _info._amounts.length,"array length must be equal");
        _mint(player, newItemId);
        _setSureinfo(newItemId,_info);
    }

    function burnWithContract(uint256 tokenId) public onlyOwner {
        _burn(tokenId);
    }
    
    function _setSureinfo(uint256 tokenId,ASK memory _info) internal{
        asks[tokenId] = _info;
    }

    function getask(uint256 _id) public view returns(ASK memory _ask,address _owner){
        _ask = asks[_id];
        _owner = ownerOf(_id);
    }
}