// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import "./LumozOGNFT.sol";

contract LumozOGConvertContract is Initializable, OwnableUpgradeable {
    struct BurnedData {
        uint256 orderIndex;
        uint256[] _tokenIds;
        uint256 blockNumber;
    }

    address public verifier;
    uint256 public maxBurnCount;
    address public OGAddress;
    mapping(address => BurnedData[]) public burnedRecords;

    bool public enabled;

    uint256[500] private __gap;

    event BurnedRecord(address owner, uint256 orderIndex, uint256[] tokenIds);

    function initialize(address _OGAddress, address _verifier, uint256 _maxBurnCount) public initializer {
        __Ownable_init_unchained();


        verifier = _verifier;
        maxBurnCount = _maxBurnCount;
        OGAddress = _OGAddress;
    }

    function getMessage(
        address _address,
        uint256 _orderIndex,
        uint256[] memory _tokenIds
    ) public pure returns (bytes memory) {
        return abi.encodePacked(_address, _orderIndex, _tokenIds);
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

    function convert(uint256 _orderIndex, uint256[] memory _tokenIds, bytes memory _signature) public {
        require(enabled, "Contract closed");
        require(_tokenIds.length <= maxBurnCount, "Maximum number of conversion exceeded");
        require(burnedRecords[msg.sender].length == _orderIndex, "Already exists");

        bytes32 messageHash = getMessageHash(getMessage(msg.sender, _orderIndex, _tokenIds));
        require(SignatureChecker.isValidSignatureNow(verifier, messageHash, _signature), "invalid signature");

        LumozOGNFT OGContract = LumozOGNFT(OGAddress);
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenID = _tokenIds[i];
            require(OGContract.ownerOf(tokenID) == msg.sender, "ERC721: caller is not token owner");
            OGContract.burn(tokenID);
        }

        burnedRecords[msg.sender].push(BurnedData(_orderIndex, _tokenIds, block.number));

        emit BurnedRecord(msg.sender, _orderIndex, _tokenIds);
    }

    function changeStatus(bool _enabled) onlyOwner public {
        enabled = _enabled;
    }

    function updateVerifier(address _verifier) onlyOwner public {
        verifier = _verifier;
    }

    function updateMaxBurnCount(uint256 _maxBurnCount) onlyOwner public {
        maxBurnCount = _maxBurnCount;
    }

    function updateTokenAddress(address _OGAddress) onlyOwner public {
        OGAddress = _OGAddress;
    }

    function getUserBurnedRecordsLength(address user) public view returns (uint256) {
        return burnedRecords[user].length;
    }

}
