// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {BagelToken} from "../src/BagelToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ZkSyncChainChecker} from "foundry-devops/src/ZkSyncChainChecker.sol";
import {DeployMerkleAirdrop} from "../script/DeployMerkleAirdrop.s.sol";

contract MaliciousToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => bool) public hasCalled;
    MerkleAirdrop public airdropContract;
    bytes32[] public s_proof;

    function setAirdropContract(address _airdrop) external {
        airdropContract = MerkleAirdrop(_airdrop);
    }

    function setProof(bytes32[] calldata proof) external {
        s_proof = proof;
    }

    function safeTransfer(address, uint256) external pure returns (bool) {
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[to] += amount;

        // Attempt reentrancy attack
        if (!hasCalled[to]) {
            hasCalled[to] = true;
            // Try to claim again - this should fail due to ReentrancyGuard
            try airdropContract.claim(to, amount, s_proof, 0, bytes32(0), bytes32(0)) {
                // This should not execute due to reentrancy guard
                console.log("REENTRANCY ATTACK SUCCEEDED - THIS IS BAD!");
                balanceOf[to] += amount; // Simulate a successful transfer
            } catch {
                console.log("Reentrancy attack prevented - good!");
            }
        }
        return true;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }

    function approve(address, uint256) external pure returns (bool) {
        return true;
    }

    function allowance(address, address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function totalSupply() external pure returns (uint256) {
        return 1000000e18;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function name() external pure returns (string memory) {
        return "Malicious Token";
    }

    function symbol() external pure returns (string memory) {
        return "EVIL";
    }
}

contract MerkleAirdropTest is ZkSyncChainChecker, Test {
    MerkleAirdrop public airdrop;
    BagelToken public token;
    MaliciousToken public maliciousToken;

    bytes32 public constant ROOT = 0x660899009c4bc1edaecf8954b0857cc9dce5556b86c43fbeb7a1c1403fd38ce9;
    uint256 public constant AMOUNT_TO_CLAIM = 25 * 1e18; // 25 tokens with 18 decimals
    uint256 public constant AMOUNT_TO_SEND = AMOUNT_TO_CLAIM * 4; // Total amount to send to 4 users
    bytes32 proofOne = 0xef54b0c83407e0c74021e9c900344391f8b30fb6c98e7689f3c6015840959d08;
    bytes32 proofTwo = 0x690db6451ed7bd75de70f3e51b667921921d120ad7e9fd352b12cf84e90a96b6;
    bytes32[] public PROOF = [proofOne, proofTwo];
    address public gasPayer;
    address user;
    uint256 userPrivateKey;
    address user1;
    uint256 user1PrivateKey;

    function setUp() public {
        if (!isZkSyncChain()) {
            console.log("Deploying on non-ZkSync chain");
            DeployMerkleAirdrop deployer = new DeployMerkleAirdrop();
            (airdrop, token) = deployer.deployMerkleAirdrop();
        } else {
            console.log("Using existing MerkleAirdrop contract on ZkSync chain");
            token = new BagelToken();
            airdrop = new MerkleAirdrop(ROOT, token);
            token.mint(token.owner(), AMOUNT_TO_SEND);
            token.transfer(address(airdrop), AMOUNT_TO_SEND);
        }
        // Initialize malicious token and user addresses
        maliciousToken = new MaliciousToken();
        (user, userPrivateKey) = makeAddrAndKey("user");
        (user1, user1PrivateKey) = makeAddrAndKey("user1");
        gasPayer = makeAddr("gasPayer");
    }

    function testReentrancyProtection() public {
        // Create airdrop with malicious token
        MerkleAirdrop maliciousAirdrop = new MerkleAirdrop(ROOT, IERC20(address(maliciousToken)));
        maliciousToken.setAirdropContract(address(maliciousAirdrop));
        maliciousToken.setProof(PROOF);

        // Sign the message hash
        bytes32 digest = maliciousAirdrop.getMessageHash(user, AMOUNT_TO_CLAIM);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        // Record initial state
        uint256 initialBalance = maliciousToken.balanceOf(user);

        // The malicious token will try to reenter, but it should be prevented
        vm.prank(gasPayer);
        maliciousAirdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);

        uint256 finalBalance = maliciousToken.balanceOf(user);

        // Should only receive the amount once, not twice
        assertEq(finalBalance, initialBalance + AMOUNT_TO_CLAIM, "User should only receive tokens once");

        // Verify the user is marked as having claimed
        bool hasClaimed = maliciousAirdrop.hasClaimed(user);
        assertTrue(hasClaimed, "User should be marked as having claimed");

        // Try to claim again - should fail with AlreadyClaimed error
        vm.expectRevert(MerkleAirdrop.MerkleAirdrop__AlreadyClaimed.selector);
        vm.prank(gasPayer);
        maliciousAirdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);
    }

    function testUserCanClaim() public {
        uint256 startingBalance = token.balanceOf(user);
        bytes32 digest = airdrop.getMessageHash(user, AMOUNT_TO_CLAIM);

        // Sign the message hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        vm.prank(gasPayer);
        airdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);

        uint256 endingBalance = token.balanceOf(user);
        assertEq(endingBalance, startingBalance + 25 * 1e18, "User should receive 25 tokens");
    }

    function testPreventDoubleClaim() public {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0xd1445c931158119b00449ffcac3c947d028c0c359c34a6646d95962b3b55c6ad;
        proof[1] = 0x690db6451ed7bd75de70f3e51b667921921d120ad7e9fd352b12cf84e90a96b6;

        // sign the message hash
        bytes32 digest = airdrop.getMessageHash(user1, AMOUNT_TO_CLAIM);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);

        // First claim should succeed
        vm.prank(gasPayer);
        airdrop.claim(user1, AMOUNT_TO_CLAIM, proof, v, r, s);

        // Second claim should fail
        vm.expectRevert(MerkleAirdrop.MerkleAirdrop__AlreadyClaimed.selector);
        vm.prank(gasPayer);
        airdrop.claim(user1, AMOUNT_TO_CLAIM, proof, v, r, s);
    }
}
