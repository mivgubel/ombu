// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Rede - micro posts with title, votes, categories (uint8), topics (max 3), and comments.
contract Rede {
    // ========== Types ==========
    uint8 public constant CATEGORY_QUEJA = 0;
    uint8 public constant CATEGORY_OPINION = 1;
    uint8 public constant CATEGORY_SUGERENCIA = 2;
    uint8 public constant CATEGORY_VIDA_UNIVERSITARIA = 3;
    uint8 public constant CATEGORY_MAX = 3;

    struct Post {
        address author;
        string title;        // NEW
        string content;
        uint256 timestamp;
        uint8 category;
        string[] topics;     // up to 3 topics
    }

    struct Comment {
        address author;
        string content;
        uint256 timestamp;
    }

    struct VoteCount {
        uint256 up;
        uint256 down;
    }

    // ========== Storage ==========
    Post[] public posts;
    mapping(address => uint256[]) private _postsByAuthor;
    mapping(uint256 => VoteCount) private _votes;
    mapping(uint256 => mapping(address => int8)) private _voteOf; 
    mapping(uint256 => Comment[]) private _comments;

    // ========== Constants ==========
    uint256 public constant MAX_LENGTH = 280;
    uint256 public constant MAX_LENGTH_TITLE = 50;
    uint256 public constant MAX_TOPICS = 3;

    // ========== Events ==========
    event PostPosted(
        uint256 indexed id,
        address indexed author,
        string title,
        string content,
        uint256 timestamp,
        uint8 category
    );

    event VoteCast(
        uint256 indexed id,
        address indexed voter,
        int8 previousVote,
        int8 newVote,
        uint256 up,
        uint256 down
    );

    event CommentPosted(
        uint256 indexed postId,
        uint256 indexed commentId,
        address indexed author,
        string content,
        uint256 timestamp
    );

    // ========== Posting ==========
    function post(
        string calldata title,
        string calldata content,
        uint8 category,
        string[] calldata topics
    ) external returns (uint256 id) {
        bytes memory bTitle = bytes(title);
        bytes memory bContent = bytes(content);

        require(bTitle.length > 0, "empty title");
        require(bTitle.length <= MAX_LENGTH_TITLE, "title too long");
        require(bContent.length > 0, "empty post");
        require(bContent.length <= MAX_LENGTH, "post too long");
        require(topics.length <= MAX_TOPICS, "too many topics");
        require(category <= CATEGORY_MAX, "invalid category");

        posts.push();
        id = posts.length - 1;

        Post storage p = posts[id];
        p.author = msg.sender;
        p.title = title;
        p.content = content;
        p.timestamp = block.timestamp;
        p.category = category;

        for (uint256 i = 0; i < topics.length; i++) {
            p.topics.push(topics[i]);
        }

        _postsByAuthor[msg.sender].push(id);

        emit PostPosted(id, msg.sender, title, content, block.timestamp, category);
    }

    function getPost(
        uint256 id
    )
        external
        view
        returns (
            address author,
            string memory title,
            string memory content,
            uint256 timestamp,
            uint8 category,
            string[] memory topics
        )
    {
        require(id < posts.length, "invalid id");
        Post storage p = posts[id];

        uint256 tlen = p.topics.length;
        string[] memory t = new string[](tlen);
        for (uint256 i = 0; i < tlen; i++) {
            t[i] = p.topics[i];
        }

        return (p.author, p.title, p.content, p.timestamp, p.category, t);
    }

    function getPostsByAuthor(address author_) external view returns (uint256[] memory) {
        return _postsByAuthor[author_];
    }

    function totalPosts() external view returns (uint256) {
        return posts.length;
    }

    function getAllPosts() external view returns (Post[] memory) {
        uint256 n = posts.length;
        Post[] memory out = new Post[](n);

        for (uint256 i = 0; i < n; i++) {
            Post storage s = posts[i];
            out[i].author = s.author;
            out[i].title = s.title;
            out[i].content = s.content;
            out[i].timestamp = s.timestamp;
            out[i].category = s.category;

            uint256 tlen = s.topics.length;
            out[i].topics = new string[](tlen);
            for (uint256 j = 0; j < tlen; j++) {
                out[i].topics[j] = s.topics[j];
            }
        }
        return out;
    }

    function getPosts(uint256 offset, uint256 limit) external view returns (Post[] memory) {
        uint256 n = posts.length;
        uint256 to = offset + limit;
        if (to > n) to = n;
        uint256 size = to - offset;

        Post[] memory page = new Post[](size);
        for (uint256 i = 0; i < size; i++) {
            Post storage s = posts[offset + i];
            page[i].author = s.author;
            page[i].title = s.title;
            page[i].content = s.content;
            page[i].timestamp = s.timestamp;
            page[i].category = s.category;

            uint256 tlen = s.topics.length;
            page[i].topics = new string[](tlen);
            for (uint256 j = 0; j < tlen; j++) {
                page[i].topics[j] = s.topics[j];
            }
        }
        return page;
    }

    // ========== Voting ==========
    function upvote(uint256 id) external {
        require(id < posts.length, "invalid id");
        int8 prev = _voteOf[id][msg.sender];
        require(prev != 1, "already upvoted");

        if (prev == -1) {
            _votes[id].down -= 1;
        }
        _votes[id].up += 1;
        _voteOf[id][msg.sender] = 1;

        emit VoteCast(id, msg.sender, prev, 1, _votes[id].up, _votes[id].down);
    }

    function downvote(uint256 id) external {
        require(id < posts.length, "invalid id");
        int8 prev = _voteOf[id][msg.sender];
        require(prev != -1, "already downvoted");

        if (prev == 1) {
            _votes[id].up -= 1;
        }
        _votes[id].down += 1;
        _voteOf[id][msg.sender] = -1;

        emit VoteCast(id, msg.sender, prev, -1, _votes[id].up, _votes[id].down);
    }

    function unvote(uint256 id) external {
        require(id < posts.length, "invalid id");
        int8 prev = _voteOf[id][msg.sender];
        require(prev != 0, "no vote");

        if (prev == 1) {
            _votes[id].up -= 1;
        } else {
            _votes[id].down -= 1;
        }
        _voteOf[id][msg.sender] = 0;

        emit VoteCast(id, msg.sender, prev, 0, _votes[id].up, _votes[id].down);
    }

    function getVotes(uint256 id) external view returns (uint256 up, uint256 down, int256 score) {
        require(id < posts.length, "invalid id");
        VoteCount storage v = _votes[id];
        up = v.up;
        down = v.down;
        score = int256(v.up) - int256(v.down);
    }

    function myVote(uint256 id) external view returns (int8) {
        require(id < posts.length, "invalid id");
        return _voteOf[id][msg.sender];
    }

    // ========== Comments ==========
    function comment(uint256 postId, string calldata content) external returns (uint256 commentId) {
        require(postId < posts.length, "invalid id");
        bytes memory b = bytes(content);
        require(b.length > 0, "empty comment");
        require(b.length <= MAX_LENGTH, "comment too long");

        _comments[postId].push(Comment({
            author: msg.sender,
            content: content,
            timestamp: block.timestamp
        }));

        commentId = _comments[postId].length - 1;

        emit CommentPosted(postId, commentId, msg.sender, content, block.timestamp);
    }

    function totalComments(uint256 postId) external view returns (uint256) {
        require(postId < posts.length, "invalid id");
        return _comments[postId].length;
    }

    function getComment(
        uint256 postId,
        uint256 index
    ) external view returns (address author, string memory content, uint256 timestamp) {
        require(postId < posts.length, "invalid id");
        require(index < _comments[postId].length, "invalid comment index");
        Comment storage c = _comments[postId][index];
        return (c.author, c.content, c.timestamp);
    }

    function getComments(uint256 postId) external view returns (Comment[] memory) {
        require(postId < posts.length, "invalid id");
        return _comments[postId];
    }
}
