// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "./LumozBaseAirdrop.sol";

contract LumozTokenAirdrop is LumozBaseAirdrop {
    function claim(uint256 rootIndex, uint256 index, uint256 amount, bytes32[] calldata merkleProof) public whenNotPaused {
        require(!isClaimed(rootIndex, index), 'cl:already claimed');
        require(rootIndex <= rootCounts, 'Invalid Root Index');
        require(amount > 0 && amount <= totalOutput, 'Invalid param');

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, msg.sender, amount));
        require(verify(merkleProof, merkleRoots[rootIndex], node), 'cl: Invalid proof');

        if (claimEndInterval > 0) {
            require(claimStartTime + claimEndInterval >= block.timestamp, 'claim end');
        }
        // Mark it claimed and send the token.
        _setClaimed(rootIndex, index);

        require(totalClaim + amount <= totalOutput, 'claim has ended');

        bool bResult = ERC20Upgradeable(tokenAddress).transfer(msg.sender, amount);
        require(bResult, 'transfer failed.');

        if (claimHistory[msg.sender] == 0) {
            allClaimAddress.push(msg.sender);
        }

        claimHistory[msg.sender] += amount;
        totalClaim += amount;
        emit Claimed(rootIndex, index, msg.sender, amount);
    }

    function claims(uint256 amount) public onlyValidAddress(msg.sender) {
        require(msg.sender == reviewAuthority);
        uint256 value = amount;
        if (amount == 0) {
            value = ERC20Upgradeable(tokenAddress).balanceOf(address(this));
        }

        bool bResult = ERC20Upgradeable(tokenAddress).transfer(msg.sender, value);
        require(bResult, 'failed');
    }
}