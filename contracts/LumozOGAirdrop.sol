// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "./LumozBaseAirdrop.sol";
import "./LumozOGNFT.sol";
import {OGLevel} from "./util.sol";

contract LumozOGAirdrop is LumozBaseAirdrop {
    uint256 public constant maxCycle = 100;

    function claim(uint256 rootIndex, uint256 index, uint256 amount, uint256 level, bytes32[] calldata merkleProof) public whenNotPaused {
        require(!isClaimed(rootIndex, index), 'cl:already claimed');
        require(rootIndex <= rootCounts, 'Invalid Root Index');
        require(amount > 0 && amount <= maxCycle && amount <= totalOutput, 'check amount');

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, msg.sender, amount, level));
        require(verify(merkleProof, merkleRoots[rootIndex], node), 'cl: Invalid proof');

        if (claimEndInterval > 0) {
            require(claimStartTime + claimEndInterval >= block.timestamp, 'claim end');
        }
        // Mark it claimed and send the token.
        _setClaimed(rootIndex, index);

        require(totalClaim + amount <= totalOutput, 'claim has ended');

        for (uint256 i = 0; i < amount; i++) {
            LumozOGNFT(tokenAddress).safeMint(msg.sender, OGLevel(level));
        }

        if (claimHistory[msg.sender] == 0) {
            allClaimAddress.push(msg.sender);
        }

        claimHistory[msg.sender] += amount;
        totalClaim += amount;
        emit Claimed(rootIndex, index, msg.sender, amount);
    }
}
