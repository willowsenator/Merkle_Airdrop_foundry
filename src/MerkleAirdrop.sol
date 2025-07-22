// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {console} from "forge-std/console.sol";

contract MerkleAirdrop is ReentrancyGuard {
    using SafeERC20 for IERC20;

    error MerkleAirdrop__InvalidProof();
    error MerkleAirdrop__AlreadyClaimed();

    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_airdropToken;
    mapping(address => bool) private s_hasClaimed;

    event Claim(address indexed account, uint256 amount);

    constructor(bytes32 merkleRoot, IERC20 airdropToken) {
        // Initialize the contract with the Merkle root
        // This is where you would store the Merkle root for verification

        i_merkleRoot = merkleRoot;
        i_airdropToken = airdropToken;
    }

    function claim(address account, uint256 amount, bytes32[] calldata merkleProof) external nonReentrant {
        if (s_hasClaimed[account]) {
            revert MerkleAirdrop__AlreadyClaimed();
        }

        // Calculate the leaf node from the account and amount
        // This is the hash of the account and amount, which will be used to verify against
        bytes32[] memory data = new bytes32[](2);
        data[0] = bytes32(uint256(uint160(account))); // Convert address to bytes32
        data[1] = bytes32(amount); // Convert amount to bytes32
        bytes32 leaf = keccak256(bytes.concat(keccak256(ltrim64(abi.encode(data)))));
        console.logBytes32(leaf);
        console.log("Expected leaf: 0xef54b0c83407e0c74021e9c900344391f8b30fb6c98e7689f3c6015840959d08");

        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            revert MerkleAirdrop__InvalidProof();
        }
        s_hasClaimed[account] = true;
        emit Claim(account, amount);
        i_airdropToken.safeTransfer(account, amount);
    }

    function hasClaimed(address account) external view returns (bool) {
        return s_hasClaimed[account];
    }

    function getAirdropToken() external view returns (IERC20) {
        return i_airdropToken;
    }

    function getMerkleRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    /// @dev Returns a slice of `_bytes` with the first 64 bytes removed.
    function ltrim64(bytes memory _bytes) internal pure returns (bytes memory) {
        return slice(_bytes, 64, _bytes.length - 64);
    }

    /// @dev Returns a slice of `_bytes` starting at index `_start` and of length `_length`.
    /// referenece: https://github.com/GNSPS/solidity-bytes-utils/blob/6458fb2780a3092bc756e737f246be1de6d3d362/contracts/BytesLib.sol#L228
    function slice(bytes memory _bytes, uint256 _start, uint256 _length) internal pure returns (bytes memory) {
        require(_length + 31 >= _length, "slice_overflow");
        require(_bytes.length >= _start + _length, "slice_outOfBounds");

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
            case 0 {
                tempBytes := mload(0x40)

                let lengthmod := and(_length, 31)
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for { let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start) } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } { mstore(mc, mload(cc)) }

                mstore(tempBytes, _length)
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            default {
                tempBytes := mload(0x40)

                mstore(tempBytes, 0)
                mstore(0x40, add(tempBytes, 0x20))
            }
        }
        return tempBytes;
    }
}
