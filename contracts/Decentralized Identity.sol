// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Identity Contract
 * @dev A smart contract for managing self-sovereign digital identities on the blockchain
 * @author Your Name
 */
contract DecentralizedIdentity {
    
    // Struct to represent an identity
    struct Identity {
        string name;
        string email;
        string profileHash; // IPFS hash of profile data
        bool isVerified;
        uint256 createdAt;
        uint256 updatedAt;
        mapping(string => string) attributes; // Dynamic attributes (e.g., "education", "employment")
        string[] attributeKeys; // To keep track of attribute keys
    }
    
    // Struct for verification requests
    struct VerificationRequest {
        address requester;
        address verifier;
        string documentHash; // IPFS hash of verification document
        bool isApproved;
        bool isProcessed;
        uint256 requestedAt;
    }
    
    // Mappings
    mapping(address => Identity) private identities;
    mapping(address => bool) public hasIdentity;
    mapping(address => bool) public authorizedVerifiers;
    mapping(uint256 => VerificationRequest) public verificationRequests;
    
    // State variables
    address public owner;
    uint256 public nextRequestId;
    uint256 public totalIdentities;
    
    // Events
    event IdentityCreated(address indexed user, string name, uint256 timestamp);
    event IdentityUpdated(address indexed user, uint256 timestamp);
    event VerificationRequested(address indexed user, uint256 requestId, uint256 timestamp);
    event IdentityVerified(address indexed user, address indexed verifier, uint256 timestamp);
    event VerifierAuthorized(address indexed verifier, uint256 timestamp);
    event AttributeAdded(address indexed user, string key, uint256 timestamp);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier onlyIdentityOwner() {
        require(hasIdentity[msg.sender], "Identity does not exist");
        _;
    }
    
    modifier onlyAuthorizedVerifier() {
        require(authorizedVerifiers[msg.sender], "Not an authorized verifier");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        nextRequestId = 1;
        totalIdentities = 0;
    }
    
    /**
     * @dev Core Function 1: Create a new decentralized identity
     * @param _name Full name of the identity holder
     * @param _email Email address of the identity holder
     * @param _profileHash IPFS hash containing additional profile information
     */
    function createIdentity(
        string memory _name,
        string memory _email,
        string memory _profileHash
    ) external {
        require(!hasIdentity[msg.sender], "Identity already exists for this address");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_email).length > 0, "Email cannot be empty");
        
        Identity storage newIdentity = identities[msg.sender];
        newIdentity.name = _name;
        newIdentity.email = _email;
        newIdentity.profileHash = _profileHash;
        newIdentity.isVerified = false;
        newIdentity.createdAt = block.timestamp;
        newIdentity.updatedAt = block.timestamp;
        
        hasIdentity[msg.sender] = true;
        totalIdentities++;
        
        emit IdentityCreated(msg.sender, _name, block.timestamp);
    }
    
    /**
     * @dev Core Function 2: Update existing identity information
     * @param _name Updated full name
     * @param _email Updated email address
     * @param _profileHash Updated IPFS hash for profile
     */
    function updateIdentity(
        string memory _name,
        string memory _email,
        string memory _profileHash
    ) external onlyIdentityOwner {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_email).length > 0, "Email cannot be empty");
        
        Identity storage identity = identities[msg.sender];
        identity.name = _name;
        identity.email = _email;
        identity.profileHash = _profileHash;
        identity.updatedAt = block.timestamp;
        
        emit IdentityUpdated(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Core Function 3: Request identity verification from authorized verifier
     * @param _verifier Address of the authorized verifier
     * @param _documentHash IPFS hash of verification documents
     */
    function requestVerification(
        address _verifier,
        string memory _documentHash
    ) external onlyIdentityOwner returns (uint256) {
        require(authorizedVerifiers[_verifier], "Verifier is not authorized");
        require(bytes(_documentHash).length > 0, "Document hash cannot be empty");
        
        uint256 requestId = nextRequestId;
        verificationRequests[requestId] = VerificationRequest({
            requester: msg.sender,
            verifier: _verifier,
            documentHash: _documentHash,
            isApproved: false,
            isProcessed: false,
            requestedAt: block.timestamp
        });
        
        nextRequestId++;
        
        emit VerificationRequested(msg.sender, requestId, block.timestamp);
        return requestId;
    }
    
    // Additional utility functions
    
    /**
     * @dev Add custom attributes to identity
     * @param _key Attribute key (e.g., "education", "skill")
     * @param _value Attribute value
     */
    function addAttribute(string memory _key, string memory _value) external onlyIdentityOwner {
        require(bytes(_key).length > 0, "Key cannot be empty");
        require(bytes(_value).length > 0, "Value cannot be empty");
        
        Identity storage identity = identities[msg.sender];
        
        // Check if key already exists
        bool exists = false;
        for (uint i = 0; i < identity.attributeKeys.length; i++) {
            if (keccak256(bytes(identity.attributeKeys[i])) == keccak256(bytes(_key))) {
                exists = true;
                break;
            }
        }
        
        if (!exists) {
            identity.attributeKeys.push(_key);
        }
        
        identity.attributes[_key] = _value;
        identity.updatedAt = block.timestamp;
        
        emit AttributeAdded(msg.sender, _key, block.timestamp);
    }
    
    /**
     * @dev Authorize a verifier (only owner)
     * @param _verifier Address to authorize as verifier
     */
    function authorizeVerifier(address _verifier) external onlyOwner {
        require(_verifier != address(0), "Invalid verifier address");
        authorizedVerifiers[_verifier] = true;
        emit VerifierAuthorized(_verifier, block.timestamp);
    }
    
    /**
     * @dev Process verification request (only authorized verifiers)
     * @param _requestId ID of the verification request
     * @param _approved Whether to approve or reject the verification
     */
    function processVerification(uint256 _requestId, bool _approved) external onlyAuthorizedVerifier {
        VerificationRequest storage request = verificationRequests[_requestId];
        require(request.verifier == msg.sender, "Not the assigned verifier");
        require(!request.isProcessed, "Request already processed");
        
        request.isApproved = _approved;
        request.isProcessed = true;
        
        if (_approved) {
            identities[request.requester].isVerified = true;
            emit IdentityVerified(request.requester, msg.sender, block.timestamp);
        }
    }
    
    // View functions
    
    /**
     * @dev Get basic identity information
     * @param _user Address of the identity holder
     */
    function getIdentity(address _user) external view returns (
        string memory name,
        string memory email,
        string memory profileHash,
        bool isVerified,
        uint256 createdAt,
        uint256 updatedAt
    ) {
        require(hasIdentity[_user], "Identity does not exist");
        Identity storage identity = identities[_user];
        
        return (
            identity.name,
            identity.email,
            identity.profileHash,
            identity.isVerified,
            identity.createdAt,
            identity.updatedAt
        );
    }
    
    /**
     * @dev Get attribute value by key
     * @param _user Address of the identity holder
     * @param _key Attribute key
     */
    function getAttribute(address _user, string memory _key) external view returns (string memory) {
        require(hasIdentity[_user], "Identity does not exist");
        return identities[_user].attributes[_key];
    }
    
    /**
     * @dev Get all attribute keys for an identity
     * @param _user Address of the identity holder
     */
    function getAttributeKeys(address _user) external view returns (string[] memory) {
        require(hasIdentity[_user], "Identity does not exist");
        return identities[_user].attributeKeys;
    }
    
    /**
     * @dev Get verification request details
     * @param _requestId ID of the verification request
     */
    function getVerificationRequest(uint256 _requestId) external view returns (
        address requester,
        address verifier,
        string memory documentHash,
        bool isApproved,
        bool isProcessed,
        uint256 requestedAt
    ) {
        VerificationRequest storage request = verificationRequests[_requestId];
        return (
            request.requester,
            request.verifier,
            request.documentHash,
            request.isApproved,
            request.isProcessed,
            request.requestedAt
        );
    }
}
