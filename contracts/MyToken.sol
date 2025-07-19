// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Burnable,
    Ownable
{
    uint256 private _nextTokenId;
    // string constant META_DATA = "https://busy-blue-ostrich.myfilebase.com/ipfs/QmV5FQP17pqXC1aseLv9CMWyYvKnj1GNBYQxYeJqSAJm7q";
    string constant META_DATA =
        "ipfs://QmV5FQP17pqXC1aseLv9CMWyYvKnj1GNBYQxYeJqSAJm7q"; // metadata的两种写法
    mapping(address => bool) public whitelist; // 白名单地址

    constructor(
        address initialOwner
    ) ERC721("MyToken", "MTK") Ownable(initialOwner) {}

    /**
     * @notice Adds an address to the whitelist.
     * @param account 地址
     */
    function addToWhitelist(address account) public onlyOwner {
        whitelist[account] = true;
    }

    /**
     * @notice Adds multiple addresses to the whitelist.
     * @param accounts 地址数组
     */
    function addToWhitelistBatch(address[] memory accounts) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            whitelist[accounts[i]] = true;
        }
    }

    /**
     * @notice Removes an address from the whitelist.
     * @param account 地址
     */
    function removeFromWhitelist(address account) public onlyOwner {
        whitelist[account] = false;
    }

    function safeMint(address to) public OnlyWhitelisted returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, META_DATA);
        return tokenId;
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    modifier OnlyWhitelisted() {
        require(whitelist[msg.sender], "Not whitelisted");
        _;
    }
}
