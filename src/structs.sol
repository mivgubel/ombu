// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.28;

// Data structure to hold Ombu posts.
struct OmbuPost {
    address author;
    string content;
    uint32 timestamp;
    uint32 upvotes;
    uint32 downvotes;
}
