// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./NFT_Permission.sol";
import "./NFT_Token.sol";

pragma solidity ^0.8.7;
contract NFTCertificate is Initializable{


    struct Certificate {
        uint256 tokenId; // ex. 2 (ERC 1155)
        string id; // linear_id
        string idCardMasking;
        string name; // ex. DMK
        string description; // ex. Digital Marketing
        string ownerName; // ex. John Doe (optional)
        string year; // ex. 2022 (optional)
        string series; // ex. 01 (optional)
        string tokenType; // CERTIFICATE
        string state; // ex. A (Active), I (Inactive)
        string fileHash;
        address issueBy; // Issuer wallet address
        uint256 issueDate;
        uint256 expireDate;
    }

    address NFTPermissionAddress;
    address NFTTokenAddress;

    using SafeMathUpgradeable for uint256;

    // external id -> token
    mapping(string => uint256) public mapId;
    // token -> cer
    mapping(uint256 => Certificate) private mapCertificate;
    // token -> type
    mapping(uint256 => string) private mapTokenType;
    // external id => role
    mapping(uint256 => string) public mapTokenRole;

    string private certificateType;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _nftPermissionAddress, address _nftTokenAddress) initializer external {

        certificateType = "CERTIFICATE";
        NFTPermissionAddress = _nftPermissionAddress;
        NFTTokenAddress = _nftTokenAddress;

    }


    event IssueCertificateEvent(Certificate);
    event VoidTokenEvent(uint256 tokenId, uint256 amount, string tokenType, string reason);

    function safeTransferCertificateFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public  {
        require(InterfaceNFTPermission(NFTPermissionAddress).checkTokenAccessRole(msg.sender, mapTokenRole[id]) || InterfaceNFTPermission(NFTPermissionAddress).checkAdminRole(msg.sender),"Invalid token access role.");
        require(InterfaceNFTPermission(NFTPermissionAddress).checkTransferRole(msg.sender),"only transfer role");

        InterfaceCertificateToken(NFTTokenAddress).safeTransferTokenFrom(from, to, id, amount, data, msg.sender, mapTokenRole[id]);
        userTransfer(id,from, to);
    }

    function safeBatchTransferCertificateFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public  {
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
        InterfaceCertificateToken(NFTTokenAddress).removeCertificateList(from, InterfaceCertificateToken(NFTTokenAddress).findCertificateIndex(from, id),  msg.sender, mapTokenRole[id]);
        if (InterfaceCertificateToken(NFTTokenAddress).findCertificateIndex(to, id) < int(0)) {
            InterfaceCertificateToken(NFTTokenAddress).addUserCertificate(to, id,  msg.sender);
        }

    }

    function issueCertificate(address _receiverAddress, Certificate memory _certificate, string memory _uri) public  {
        require(mapId[_certificate.id] == 0, "ID already exist.");
        require(InterfaceNFTPermission(NFTPermissionAddress).checkMinterRole(msg.sender),"only minter role");
        require(InterfaceNFTPermission(NFTPermissionAddress).checkAccessRole(msg.sender),"Need token access role.");


        uint256 currentTokenId = InterfaceCertificateToken(NFTTokenAddress).currentTokenId();

        mapTokenType[currentTokenId] = certificateType;
        mapId[_certificate.id] = currentTokenId;

        _certificate.issueBy = msg.sender;
        _certificate.tokenId = currentTokenId;
        _certificate.issueDate = block.timestamp;
        _certificate.tokenType = certificateType;
        _certificate.state = "A";

        InterfaceCertificateToken(NFTTokenAddress).mintToken(_receiverAddress, _certificate.tokenId, 1, "", msg.sender, address(this), _certificate.id, _uri, certificateType);
        InterfaceCertificateToken(NFTTokenAddress).addUserCertificate(_receiverAddress, _certificate.tokenId,  msg.sender);
        mapCertificate[currentTokenId] = _certificate;
        mapTokenRole[currentTokenId] = InterfaceNFTPermission(NFTPermissionAddress).getAddressRole(msg.sender);

        emit IssueCertificateEvent(_certificate);
    }

    function voidCertificate(address _target, string memory _id, uint256 _amount, string memory _reason) public  {
        require(mapId[_id] != 0, "Certificate isn't exist");
        require(InterfaceNFTPermission(NFTPermissionAddress).checkBurnerRole(msg.sender),"only burner role");
        require(InterfaceNFTPermission(NFTPermissionAddress).checkTokenAccessRole(msg.sender, mapTokenRole[mapId[_id]]) || InterfaceNFTPermission(NFTPermissionAddress).checkAdminRole(msg.sender),"Invalid token access role.");


        mapCertificate[mapId[_id]].state = "I";
        InterfaceCertificateToken(NFTTokenAddress).burnToken(_target, mapId[_id], _amount, msg.sender, mapTokenRole[mapId[_id]]);
        InterfaceCertificateToken(NFTTokenAddress).removeCertificateList(_target, InterfaceCertificateToken(NFTTokenAddress).findCertificateIndex(_target, mapId[_id]), msg.sender, mapTokenRole[mapId[_id]]);
        emit VoidTokenEvent(mapId[_id], _amount, mapTokenType[mapId[_id]], _reason);
    }

    function certificateInfo(uint256 _tokenId) public view returns (Certificate memory){
        require(keccak256(abi.encode(mapTokenType[_tokenId])) == keccak256(abi.encode(certificateType)), "Not certificate token.");
        return mapCertificate[_tokenId];
    }

}