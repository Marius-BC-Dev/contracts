// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import "./LumozOGNFT.sol";
import {OGLevel} from "./util.sol";

contract LumozOGClaimContract is Initializable, OwnableUpgradeable {
    struct ClaimedData {
        uint256 orderIndex;
        uint256 level;
        uint256 number;
        uint256 blockNumber;
    }

    address public verifier;
    uint256 public maxClaimedCount;
    address public OGAddress;
    mapping(address => ClaimedData[]) public claimedRecords;

    bool public claimEnabled;

    uint256[500] private __gap;

    event ClaimedRecord(address _owner, uint256 _orderIndex, uint256 _level, uint256 _count);

    function initialize(address _OGAddress, address _verifier, uint256 _maxClaimedCount) public initializer {
        __Ownable_init_unchained();


        verifier = _verifier;
        maxClaimedCount = _maxClaimedCount;
        OGAddress = _OGAddress;
    }

    function getMessage(
        address _address,
        uint256 _orderIndex,
        uint256 _level,
        uint256 _count
    ) public pure returns (bytes memory) {
        return abi.encodePacked(_address, _orderIndex, _level, _count);
    }

    function getMessageHash(bytes memory _message)
    public
    pure
    returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(string.concat("\x19Ethereum Signed Message:\n", Strings.toString(_message.length)), _message)
        );
    }

    function claim(uint256 _orderIndex, uint256 _level, uint256 _count, bytes memory _signature) public {
        require(claimEnabled, "Contract closed");
        require(_count <= maxClaimedCount, "Maximum number of claim exceeded");
        require(claimedRecords[msg.sender].length == _orderIndex, "Already exists");

        bytes32 messageHash = getMessageHash(getMessage(msg.sender, _orderIndex, _level, _count));
        require(SignatureChecker.isValidSignatureNow(verifier, messageHash, _signature), "invalid signature");
        OGLevel level = OGLevel(_level);
        for (uint256 i = 0; i < _count; i++) {
            LumozOGNFT(OGAddress).safeMint(msg.sender, level);
        }

        claimedRecords[msg.sender].push(ClaimedData(_orderIndex, _level, _count, block.number));

        emit ClaimedRecord(msg.sender, _orderIndex, _level, _count);
    }

    function changeStatus(bool _claimEnabled) onlyOwner public {
        claimEnabled = _claimEnabled;
    }

    function updateVerifier(address _verifier) onlyOwner public {
        verifier = _verifier;
    }

    function updateMaxClaimedCount(uint256 _maxClaimedCount) onlyOwner public {
        maxClaimedCount = _maxClaimedCount;
    }

    function updateTokenAddress(address _OGAddress) onlyOwner public {
        OGAddress = _OGAddress;
    }

    function getUserClaimedRecordsLength(address user) public view returns (uint256) {
        return claimedRecords[user].length;
    }

}
