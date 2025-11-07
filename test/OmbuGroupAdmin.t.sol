// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {Ombu} from "../src/Ombu.sol";

contract MockSemaphoreAdmin {
    uint256 public nextGroupId;
    uint256 public updatedGroupId;
    address public updatedNewAdmin;
    uint256 public acceptedGroupId;

    function createGroup() external returns (uint256) {
        return nextGroupId++;
    }

    function updateGroupAdmin(uint256 groupId, address newAdmin) external {
        updatedGroupId = groupId;
        updatedNewAdmin = newAdmin;
    }

    function acceptGroupAdmin(uint256 groupId) external {
        acceptedGroupId = groupId;
    }
}

contract OmbuGroupAdminTest is Test {
    Ombu internal ombu;
    MockSemaphoreAdmin internal sem;

    address internal admin = address(0xA11CE);
    address internal newAdmin = address(0xBEEF);

    function setUp() public {
        sem = new MockSemaphoreAdmin();
        ombu = new Ombu(address(sem), admin);
    }

    function testChangeGroupAdminForwardsToSemaphore() public {
        uint256 groupId = 0; // created in constructor via mock
        ombu.changeGroupAdmin(groupId, newAdmin);

        assertEq(sem.updatedGroupId(), groupId, "group id forwarded");
        assertEq(sem.updatedNewAdmin(), newAdmin, "new admin forwarded");
    }

    function testAcceptGroupAdminForwardsToSemaphore() public {
        uint256 groupId = 0;
        ombu.acceptGroupAdmin(groupId);
        assertEq(sem.acceptedGroupId(), groupId, "accept forwarded");
    }
}
