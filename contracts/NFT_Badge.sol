// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./NFT_Permission.sol";
import "./NFT_Token.sol";

pragma solidity ^0.8.7;
contract NFTBadge is Initializable{

    struct Attribute {
        string key; // ex. 1
        string id; // linear_id
        string label; // ex. Skill
        string name; // ex. L
        string description; // ex. Learning
        uint256 sequence; // ex. 1
    }
    // Learning Hour
    struct Badge {
        uint256 tokenId; // ex. 1 (ERC 1155)
        string id; // linear_id
        string idCardMasking;
        string name; // ex. DMK
        string description; // ex. Digital Marketing
        string ownerName; // ex. John Doe (optional)
        string tokenType; // BADGE
        uint256 amount; // ex. 5
        string state; // ex. A (Active), I (Inactive)
        address issueBy; // Issuer wallet address
        uint256 issueDate;
        uint256 expireDate;
    }

    address NFTPermissionAddress;
    address NFTTokenAddress;

    using SafeMathUpgradeable for uint256;

    // external id -> token
    mapping(string => uint256) public mapId;
    // token -> badge
    mapping(uint256 => Badge) private mapBadge;
    // token -> type
    mapping(uint256 => string) private mapTokenType;
    // badge -> attribute
    mapping(uint256 => Attribute[]) private mapAttribute;
    // external id => role
    mapping(uint256 => string) public mapTokenRole;


    string private badgeType;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _nftPermissionAddress, address _nftTokenAddress) initializer external  {
        badgeType = "BADGE";
        NFTPermissionAddress = _nftPermissionAddress;
        NFTTokenAddress = _nftTokenAddress;
    }

    Attribute [] private attribute;

    event IssueBadgeEvent(Badge,Attribute[]);
    event VoidTokenEvent(uint256 tokenId, uint256 amount, string tokenType, string reason);

    function safeTransferBadgeFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public  {
        require(InterfaceNFTPermission(NFTPermissionAddress).checkTokenAccessRole(msg.sender, mapTokenRole[id]) || InterfaceNFTPermission(NFTPermissionAddress).checkAdminRole(msg.sender),"Invalid token access role.");
        require(InterfaceNFTPermission(NFTPermissionAddress).checkTransferRole(msg.sender),"only transfer role");

        InterfaceCertificateToken(NFTTokenAddress).safeTransferTokenFrom(from, to, id, amount, data, msg.sender, mapTokenRole[id]);
        userTransfer(id,from, to);
    }

    function safeBatchTransferBadgeFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public  {
        require(InterfaceNFTPermission(NFTPermissionAddress).checkTransferRole(msg.sender),"only transfer role");
        for (uint i = 0; i < ids.length; i++) {
            require(InterfaceNFTPermission(NFTPermissionAddress).checkTokenAccessRole(msg.sender, mapTokenRole[ids[i]]) || InterfaceNFTPermission(NFTPermissionAddress).checkAdminRole(msg.sender),"Invalid token access role.");
            require(ids[i] > 0, "token 0 isn't exist.");
        }
        InterfaceCertificateToken(NFTTokenAddress).safeBatchTransferTokenFrom(from, to, ids, amounts, data, msg.sender, InterfaceNFTPermission(NFTPermissionAddress).getAddressRole(msg.sender));
        for (uint i = 0; i < ids.length; i++) {
            userTransfer(ids[i],from, to);
        }

    }


    function userTransfer(uint256 id, address from, address to) private {

        InterfaceCertificateToken(NFTTokenAddress).removeBadgeList(from, InterfaceCertificateToken(NFTTokenAddress).findBadgeIndex(from, id), msg.sender, mapTokenRole[id]);
        if (InterfaceCertificateToken(NFTTokenAddress).findBadgeIndex(to, id) < int(0)) {
            InterfaceCertificateToken(NFTTokenAddress).addUserBadge(to, id,  msg.sender);
        }
    }

    function issueBadge(address _receiverAddress, Badge memory _badge, string memory _uri, Attribute [] memory _attributes) public {
        require(mapId[_badge.id] == 0, "ID already exist.");
        require(_badge.amount > 0, "Cannot mint zero token");
        require(InterfaceNFTPermission(NFTPermissionAddress).checkMinterRole(msg.sender),"only minter role");
        require(InterfaceNFTPermission(NFTPermissionAddress).checkAccessRole(msg.sender),"Need token access role.");

        uint256 currentTokenId = InterfaceCertificateToken(NFTTokenAddress).currentTokenId();
        mapTokenType[currentTokenId] = badgeType;
        mapId[_badge.id] = currentTokenId;
        Attribute [] storage storageAttribute = attribute;
        for (uint i = 0; i < _attributes.length; i++) {
            storageAttribute.push(_attributes[i]);
        }
        mapAttribute[currentTokenId] = storageAttribute;
        delete attribute;

        _badge.issueBy = msg.sender;
        _badge.tokenId = currentTokenId;
        _badge.issueDate = block.timestamp;
        _badge.tokenType = badgeType;
        _badge.state = "A";

        InterfaceCertificateToken(NFTTokenAddress).mintToken(_receiverAddress, _badge.tokenId, _badge.amount, "", msg.sender, address(this), _badge.id, _uri, badgeType);

        InterfaceCertificateToken(NFTTokenAddress).addUserBadge(_receiverAddress,_badge.tokenId,  msg.sender);
        mapBadge[currentTokenId] = _badge;

        mapTokenRole[currentTokenId] = InterfaceNFTPermission(NFTPermissionAddress).getAddressRole(msg.sender);

        emit IssueBadgeEvent(_badge,_attributes);
    }

    function voidBadge(address _target, string memory _id, uint256 _amount, string memory _reason) public {
        require(mapId[_id] != 0, "Badge isn't exist");
        require(InterfaceNFTPermission(NFTPermissionAddress).checkBurnerRole(msg.sender),"only burner role");
        require(InterfaceNFTPermission(NFTPermissionAddress).checkTokenAccessRole(msg.sender, mapTokenRole[mapId[_id]]) || InterfaceNFTPermission(NFTPermissionAddress).checkAdminRole(msg.sender),"Invalid token access role.");

        mapBadge[mapId[_id]].amount.sub(_amount);
        mapBadge[mapId[_id]].state = "I";

        InterfaceCertificateToken(NFTTokenAddress).burnToken(_target, mapId[_id], _amount, msg.sender, mapTokenRole[mapId[_id]]);
        InterfaceCertificateToken(NFTTokenAddress).removeBadgeList(_target, InterfaceCertificateToken(NFTTokenAddress).findBadgeIndex(_target, mapId[_id]), msg.sender, mapTokenRole[mapId[_id]]);

        emit VoidTokenEvent(mapId[_id], _amount, mapTokenType[mapId[_id]], _reason);
    }

    function badgeInfo(uint256 _tokenId) public view returns (Badge memory){
        require(keccak256(abi.encode(mapTokenType[_tokenId])) == keccak256(abi.encode(badgeType)), "Not badge token.");
        return mapBadge[_tokenId];
    }

    function attributeInfo(uint256 _tokenId) public view returns (Attribute [] memory){
        require(keccak256(abi.encode(mapTokenType[_tokenId])) == keccak256(abi.encode(badgeType)), "Not badge token.");
        return mapAttribute[_tokenId];
    }

}