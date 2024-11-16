// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

interface IOGNFT {
    function burn(uint256 tokenId) external;
    function balanceOf(address owner) external returns (uint256);
    function ownerOf(uint256 tokenId) external returns (address);
    function getAmount(uint256 _tokenID) external view returns(uint256);
}
