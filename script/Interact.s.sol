// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";


contract ClaimAirdrop is Script {
     address CLAIMING_ADDRESS = 0x29E3b139f4393aDda86303fcdAa35F60Bb7092bF; 
        uint256 CLAIMING_AMOUNT = 25e18; // 25 tokens
        bytes32 PROOF_ONE = 0xd1445c931158119b00449ffcac3c947d028c0c359c34a6646d95962b3b55c6ad;
        bytes32 PROOF_TWO = 0x690db6451ed7bd75de70f3e51b667921921d120ad7e9fd352b12cf84e90a96b6;
        bytes32[] proof = [PROOF_ONE, PROOF_TWO];
        bytes private SIGNATURE = hex"542edfc1fd4c925eb69df98e4149b00452ebe6b82ec737edfd8753bae65791166460d4486da190075cfb2a647cf7ff599264bcfc91cccfe587fb291296748c941b";

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