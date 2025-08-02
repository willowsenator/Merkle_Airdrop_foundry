// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";

contract ClaimAirdrop is Script {
    address CLAIMING_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 CLAIMING_AMOUNT = 25e18; // 25 tokens
    bytes32 PROOF_ONE = 0x8ebcc963f0588d1ded1ebd0d349946755f27e95d1917f9427a207d8935e04d4b;
    bytes32 PROOF_TWO = 0x67ac38a0ee927516de8ed257ce3ecc9b1c02daf12cde2da8ffaf12582431f3d7;
    bytes32[] proof = [PROOF_ONE, PROOF_TWO];
    bytes private SIGNATURE =
        hex"6c576a2bcd6ec720be706c4a336ac69c3cfee293689bca8205e9ff240e2d69c50084e9509ae54535c86062b05a91e5da8bb22d517e7f72ba879823fd3f56c9361b";

    error __ClaimAirdrop__InvalidSignatureLength();

    function claimAirdrop(address airdrop) public {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(SIGNATURE);
        vm.startBroadcast();
        MerkleAirdrop(airdrop).claim(CLAIMING_ADDRESS, CLAIMING_AMOUNT, proof, v, r, s);
        vm.stopBroadcast();
    }

    function splitSignature(bytes memory sig) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        if (sig.length != 65) {
            revert __ClaimAirdrop__InvalidSignatureLength();
        }
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function run() external {
        address mostRecentDeployed = DevOpsTools.get_most_recent_deployment("MerkleAirdrop", block.chainid);
        claimAirdrop(mostRecentDeployed);
    }
}
