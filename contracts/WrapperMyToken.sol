// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.28;

import {MyToken} from "./MyToken.sol";

contract WrapperMyToken is MyToken {

    address public receiver;

    constructor(address initialOwner) MyToken(initialOwner) {}

    function mintTokenWithSpecificTokenId(
        address to,
        uint256 tokenId
    ) public onlyReceiver returns (uint256) {
        _safeMint(to, tokenId);
        return tokenId;
    }

    function setReceiver(address newReceiver) public {
        require(msg.sender == receiver, "Only current receiver can set a new receiver");
        receiver = newReceiver;
    }

    modifier onlyReceiver() {
        require(msg.sender == receiver, "Caller is not the receiver");
        _;
    }
}
