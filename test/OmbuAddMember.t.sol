// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {Ombu} from "../src/Ombu.sol";

// Minimal mock of ISemaphore to test Ombu.addMember logic without external dependency.
contract MockSemaphore {
    uint256 public nextGroupId;
    uint256 public lastGroupId;
    uint256 public lastIdentityCommitment;

    // groupId => identityCommitment => isMember
    mapping(uint256 => mapping(uint256 => bool)) private _isMember;

    function createGroup() external returns (uint256) {
        // Return current and then increment; Ombu constructor expects first group to be ID 0.
        return nextGroupId++;
    }

    function addMember(uint256 groupId, uint256 identityCommitment) external {
        lastGroupId = groupId;
        lastIdentityCommitment = identityCommitment;
        _isMember[groupId][identityCommitment] = true;
    }

    function removeMember(uint256 groupId, uint256 identityCommitment, uint256[] calldata) external {
        _isMember[groupId][identityCommitment] = false;
    }

    function isMember(uint256 groupId, uint256 identityCommitment) external view returns (bool) {
        return _isMember[groupId][identityCommitment];
    }

    // Alias matching ISemaphoreGroups interface used by Ombu.isGroupMember
    function hasMember(uint256 groupId, uint256 identityCommitment) external view returns (bool) {
        return _isMember[groupId][identityCommitment];
    }
}

contract OmbuAddMemberTest is Test {
    Ombu internal ombu;
    MockSemaphore internal sem;
    address internal admin = address(0xA11CE);
    address internal user = address(0xB0B);

    function setUp() public {
        sem = new MockSemaphore();
        ombu = new Ombu(address(sem), admin);
    }

    function testAddMember() public {
        // Constructor created group 0 via mock semaphore.
        uint256 groupId = 0;
        uint256 identityCommitment = 12345678901234567890; // sample commitment value

        // Simulate call from an arbitrary user (anyone can add currently per contract comment).
        vm.prank(user);
        ombu.addMember(groupId, identityCommitment);

        assertEq(sem.lastGroupId(), groupId, "Group id forwarded");
        assertEq(sem.lastIdentityCommitment(), identityCommitment, "Identity commitment forwarded");
        assertTrue(sem.isMember(groupId, identityCommitment), "Member stored in mock semaphore");
    }

    function testIsGroupMemberTrue() public {
        uint256 groupId = 0;
        uint256 identityCommitment = 111;
        ombu.addMember(groupId, identityCommitment);
        // Ombu view should return true.
        bool exists = ombu.isGroupMember(groupId, identityCommitment);
        assertTrue(exists, "Expected member to exist");
    }

    function testIsGroupMemberFalse() public view {
        uint256 groupId = 0;
        uint256 identityCommitment = 999999;
        bool exists = ombu.isGroupMember(groupId, identityCommitment);
        assertFalse(exists, "Expected member not to exist");
    }
}
