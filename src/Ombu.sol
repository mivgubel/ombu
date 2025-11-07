//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ISemaphore} from "./ISemaphore.sol";
import {ISemaphoreGroups} from "./ISemaphoreGroups.sol";
import {OmbuPost} from "./structs.sol";

// Contract to manage the Ombu data e interoperate with Semaphore.

contract Ombu {
    // semaphore arbitrum sepolia address:0x8A1fd199516489B0Fb7153EB5f075cDAC83c693D
    ISemaphore public semaphore;
    uint256 public groupCounter;
    address public admin;

    // couter for the number of posts created, so we can follow an incremental id for posts.
    mapping(uint256 groupId => uint256 postIDCounter) public groupPostCounters;
    //uint256 public postIDCounter;

    // groups ids created in semaphore.
    uint256[] public groups;

    //mapping to save a name for each group. starting from groupId 0.
    mapping(uint256 groupId => string name) public groupNames;

    // mapping to save posts for group.
    mapping(uint256 groupId => mapping(uint256 ombuPostId => OmbuPost post)) public groupPosts;

    //mapping to save subPost for each Post.
    mapping(uint256 groupId => mapping(uint256 ombuPostId => mapping(uint256 subPostId => OmbuPost subPost))) public
        postSubPosts;

    // mapping to save the user's vote in any main post.
    mapping(address user => mapping(uint256 groupId => mapping(uint256 postId => bool hasVoted))) public userPostVotes;
    // mapping to save the user's vote in any sub post.
    mapping(
        address user
            => mapping(uint256 groupId => mapping(uint256 postId => mapping(uint256 subPostId => bool hasVoted)))
    ) public userSubPostVotes;

    //Only Adming Guard.
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not Allowed");
        _;
    }

    event change_Admin(address _newAdmin);

    constructor(address _semaphoreAddress, address _ombuAdmin) {
        semaphore = ISemaphore(_semaphoreAddress);
        admin = _ombuAdmin;
        // semaphore inicia con Id 0 = Invisible Garden.
        uint256 groupId = semaphore.createGroup();
        groupCounter++;
        // save the groups ids for later reference.
        groups.push(groupId);
        groupNames[groupId] = "Invisible Garden";
    }

    /****** Functions to Manage Post *****/
    // Function to create a main post in a group, another function will create subposts.
    //@note confirmar si el autor debe ser msg.sender o un identityCommitment.
    function createMainPost(uint256 _groupId, string calldata _content) external {
        OmbuPost memory newPost = OmbuPost({
            author: msg.sender, content: _content, timestamp: uint32(block.timestamp), upvotes: 0, downvotes: 0
        });
        // post counter starts from 1, while groups ID can start from 0, because semaphore starts from group ID = 0.
        uint256 postIDCounter = groupPostCounters[_groupId];
        postIDCounter++;
        groupPostCounters[_groupId] = postIDCounter;
        // save the post in the mapping.
        groupPosts[_groupId][postIDCounter] = newPost;
    }

    // function to create subPosts, attached to a main post.
    //@note confirmar si el autor debe ser msg.sender o un identityCommitment.
    function createSubPost(uint256 _groupId, uint256 _mainPostId, string calldata _content) external {
        OmbuPost storage post = groupPosts[_groupId][_mainPostId];
        require(post.author != address(0), "Main Post does not exist");

        OmbuPost memory newSubPost = OmbuPost({
            author: msg.sender, content: _content, timestamp: uint32(block.timestamp), upvotes: 0, downvotes: 0
        });
        uint256 subPostCounter = 1;
        postSubPosts[_groupId][_mainPostId][subPostCounter] = newSubPost;
    }

    // el usuario solo debe poder votar una vez por post o subpost, ya sea a favor o en contra.
    // Function to vote on a main post.
    function voteOnPost(uint256 _groupId, uint256 _postId, bool _isUpvote) external {
        OmbuPost storage post = groupPosts[_groupId][_postId];
        require(post.author != address(0), "Post does not exist");

        bool hasVoted = userPostVotes[msg.sender][_groupId][_postId];
        require(!hasVoted, "User has already voted on this post");

        if (_isUpvote) {
            post.upvotes += 1;
        } else {
            post.downvotes += 1;
        }
        userPostVotes[msg.sender][_groupId][_postId] = true;
    }

    // Function to vote on a sub post.
    function voteOnSubPost(uint256 _groupId, uint256 _postId, uint256 _subPostId, bool _isUpvote) external {
        /* OmbuPost storage subPost = postSubPosts[_groupId][_postId][_subPostId];
        require(subPost.author != address(0), "SubPost does not exist");

        bool hasVoted = userSubPostVotes[msg.sender][_groupId][_postId][_subPostId];
        require(!hasVoted, "User has already voted on this subpost"); */
    }

    // function to edit a post and also a function to edit a subpost.

    // function to delete a vote on post or subpost.

    /****** Functions to Manage Groups *****/

    // Create a new group in Semaphore.
    function createGroup(string calldata _name) external onlyAdmin returns (uint256) {
        uint256 groupId = semaphore.createGroup();
        groupNames[groupId] = _name;
        groupCounter++;
        // save the groups ids
        groups.push(groupId);
        return groupId;
    }

    // Add member to a group.
    // For now anyone can add members, so the user can be add in the same Tx they created their identity commitment.
    function addMember(uint256 _groupId, uint256 _identityCommitment) external {
        semaphore.addMember(_groupId, _identityCommitment);
    }

    // function to remove member from a group.
    function removeMember(uint256 _groupId, uint256 _identityCommitment, uint256[] calldata _merkleProofSiblings)
        external
        onlyAdmin
    {
        semaphore.removeMember(_groupId, _identityCommitment, _merkleProofSiblings);
    }

    // function to update the contract admin.
    function changeAdmin(address _newAdmin) external onlyAdmin {
        admin = _newAdmin;
        emit change_Admin(_newAdmin);
    }
    //@note function to check if an identity commitment is member of a group.
    // function to change the group admin in semaphore.
    //@note para actualizar el admin del grupo hay que llamar a la funcion de semaphore directamente primero updateGroupAdmin por el admin
    // del grupo y despues el nuevo admin debe llamar a acceptGroupAdmin para aceptar el rol.
}
