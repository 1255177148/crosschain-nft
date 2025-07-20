// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.28;

import {MyToken} from "./MyToken.sol";
import "hardhat/console.sol";

contract WrapperMyToken is MyToken {

    constructor(address initialOwner) MyToken(initialOwner) {}

    function mintTokenWithSpecificTokenId(
        address to,
        uint256 tokenId
    ) public OnlyWhitelisted returns (uint256) {
        _safeMint(to, tokenId);
        return tokenId;
    }


}
