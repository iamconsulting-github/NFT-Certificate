// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./NFT_Permission.sol";

interface InterfaceCertificateToken {
    function currentTokenId() external view returns (uint256);
    function burnToken(address _account, uint256 _id, uint256 _amount, address _sender, string memory _role) external;
    function mintToken(address _account, uint256 _id, uint256 _amount, bytes memory _data, address _sender, address _contractAddress, string memory _externalId, string memory _uri, string memory _tokenType) external;
    function safeTransferTokenFrom(address _from, address _to, uint256 _id, uint256 _amount, bytes memory _data, address _sender, string memory _role) external;
    function safeBatchTransferTokenFrom(address _from, address _to, uint256[] memory _ids, uint256[] memory _amounts, bytes memory _data, address _sender, string memory _role) external;
    //badge
    function addUserBadge(address _user, uint256 _tokenId, address _sender) external;
    function findBadgeIndex(address _receiver, uint256 _tokenId) external view returns (int);
    function removeBadgeList(address _receiver, int _index, address _sender, string memory _role) external;
    //certificate
    function addUserCertificate(address _user, uint256 _tokenId, address _sender) external;
    function findCertificateIndex(address _receiver, uint256 _tokenId) external view returns (int);
    function removeCertificateList(address _receiver, int _index, address _sender, string memory _role) external;

}


contract CertificateToken is Initializable, ERC1155Upgradeable, ERC1155BurnableUpgradeable, AccessControlUpgradeable, InterfaceCertificateToken {

    struct TokenInfo {
        address contractAddress;
        string externalId;
        string tokenType;
        string uri;
    }

    mapping(uint256 => TokenInfo) mapTokenInfo;
    // walletAddress => badge list
    mapping(address => uint256[]) private mapUserBadge;
    // walletAddress => certificate list
    mapping(address => uint256[]) private mapUserCertificate;

    address NFTPermissionAddress;
    string public TokenName;

    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private tokenId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory _tokenName, address _nftPermissionAddress) initializer public {
        __ERC1155_init("");
        __ERC1155Burnable_init();
        __AccessControl_init();
        TokenName = _tokenName;
        NFTPermissionAddress = _nftPermissionAddress;
        tokenId.increment();
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC1155Upgradeable, AccessControlUpgradeable)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function setTokenName(string memory _tokenName) public {
        TokenName = _tokenName;
    }

    function setUri(uint256 _tokenId, string memory _uri) public {
        require(InterfaceNFTPermission(NFTPermissionAddress).checkAdminRole(msg.sender),"only admin role.");
        require(_tokenId < tokenId.current() && _tokenId != 0, "token isn't exist");
        mapTokenInfo[_tokenId].uri = _uri;
    }

    function name() external view returns (string memory) {
        return TokenName;
    }

    function symbol() external pure returns (string memory) {
        return "CERT";
    }

    function currentTokenId() external view override returns (uint256) {
        return tokenId.current();
    }

    function uri(uint256 _tokenId) public override view returns (string memory) {
        return mapTokenInfo[_tokenId].uri;
    }

    function burnToken(address _account, uint256 _id, uint256 _amount, address _sender, string memory _role) external override {
        require(InterfaceNFTPermission(NFTPermissionAddress).checkBurnerRole(_sender),"only burner role");
        require(InterfaceNFTPermission(NFTPermissionAddress).checkTokenAccessRole(_sender, _role) || InterfaceNFTPermission(NFTPermissionAddress).checkAdminRole(_sender),"Invalid token access role.");
        _burn(_account, _id, _amount);
    }

    function mintToken(address _account, uint256 _id, uint256 _amount, bytes memory _data, address _sender, address _contractAddress, string memory _externalId, string memory _uri, string memory _tokenType) external override {
        require(InterfaceNFTPermission(NFTPermissionAddress).checkMinterRole(_sender),"only minter role");
        require(InterfaceNFTPermission(NFTPermissionAddress).checkAccessRole(_sender),"Need token access role.");
        _mint(_account, _id, _amount, _data);

        TokenInfo memory tokenInfo = TokenInfo(_contractAddress, _externalId, _tokenType, _uri);

        mapTokenInfo[_id] = tokenInfo;
        tokenId.increment();
    }

    function safeTransferTokenFrom(address _from, address _to, uint256 _id, uint256 _amount, bytes memory _data, address _sender, string memory _role) external override   {
        require(InterfaceNFTPermission(NFTPermissionAddress).checkTransferRole(_sender),"only transfer role");
        require(InterfaceNFTPermission(NFTPermissionAddress).checkTokenAccessRole(_sender, _role) || InterfaceNFTPermission(NFTPermissionAddress).checkAdminRole(_sender),"Invalid token access role.");
        _safeTransferFrom(_from, _to, _id, _amount, _data);
    }

    function safeBatchTransferTokenFrom(address _from, address _to, uint256[] memory _ids, uint256[] memory _amounts, bytes memory _data, address _sender, string memory _role) external override  {
        require(InterfaceNFTPermission(NFTPermissionAddress).checkTransferRole(_sender),"only transfer role");
        for (uint i = 0; i < _ids.length; i++) {
            require(InterfaceNFTPermission(NFTPermissionAddress).checkTokenAccessRole(_sender, _role) || InterfaceNFTPermission(NFTPermissionAddress).checkAdminRole(_sender),"Invalid token access role.");
            require(_ids[i] > 0, "token 0 isn't exist.");
        }
        _safeBatchTransferFrom(_from, _to, _ids, _amounts, _data);
    }

    function getTokenInfo(uint _id) public view returns (TokenInfo memory){
        return mapTokenInfo[_id];
    }

    // Badge
    function addUserBadge(address _user, uint256 _tokenId, address _sender) external override {
        require(InterfaceNFTPermission(NFTPermissionAddress).checkMinterRole(_sender) || InterfaceNFTPermission(NFTPermissionAddress).checkTransferRole(_sender),"only minter role or transfer role");
        mapUserBadge[_user].push(_tokenId);
    }

    function findBadgeIndex(address _receiver, uint256 _tokenId) external override view returns (int) {
        uint256[] storage list = mapUserBadge[_receiver];
        for (uint i = 0; i < list.length; i++) {
            if (list[i] == _tokenId) {
                return int(i);
            }
        }
        return - 1;
    }

    function removeBadgeList(address _receiver, int _index, address _sender, string memory _role) external override {
        require(InterfaceNFTPermission(NFTPermissionAddress).checkBurnerRole(_sender),"only burner role");
        require(InterfaceNFTPermission(NFTPermissionAddress).checkTokenAccessRole(_sender, _role) || InterfaceNFTPermission(NFTPermissionAddress).checkAdminRole(_sender),"Invalid token access role.");
        require(_index >= 0, "not found index");
        uint256 [] storage mapList = mapUserBadge[_receiver];
        require(uint(_index) < mapList.length, "not found index");
        if (balanceOf(_receiver, mapList[uint(_index)]) == 0) {
            for (uint i = uint(_index); i < mapList.length - 1; i++) {
                mapList[i] = mapList[i + 1];
            }
            mapList.pop();
            mapUserBadge[_receiver] = mapList;
        }
    }

    function listUserBadge(address _wallet) public view returns (uint256[] memory){
        return mapUserBadge[_wallet];
    }

    // Certificate
    function addUserCertificate(address _user, uint256 _tokenId, address _sender) external override {
        require(InterfaceNFTPermission(NFTPermissionAddress).checkMinterRole(_sender) || InterfaceNFTPermission(NFTPermissionAddress).checkTransferRole(_sender),"only minter role or transfer role");
        mapUserCertificate[_user].push(_tokenId);
    }

    function findCertificateIndex(address _receiver, uint256 _tokenId) external override view returns (int) {
        uint256[] storage list = mapUserCertificate[_receiver];
        for (uint i = 0; i < list.length; i++) {
            if (list[i] == _tokenId) {
                return int(i);
            }
        }
        return - 1;
    }

    function removeCertificateList(address _receiver, int _index, address _sender, string memory _role) external override  {
        require(InterfaceNFTPermission(NFTPermissionAddress).checkBurnerRole(_sender),"only burner role");
        require(InterfaceNFTPermission(NFTPermissionAddress).checkTokenAccessRole(_sender, _role) || InterfaceNFTPermission(NFTPermissionAddress).checkAdminRole(_sender),"Invalid token access role.");
        require(_index >= 0, "not found index");
        uint256 [] storage mapList = mapUserCertificate[_receiver];
        require(uint(_index) < mapList.length, "not found index");
        if (balanceOf(_receiver, mapList[uint(_index)]) == 0) {
            for (uint i = uint(_index); i < mapList.length - 1; i++) {
                mapList[i] = mapList[i + 1];
            }
            mapList.pop();
            mapUserCertificate[_receiver] = mapList;
        }
    }

    function listUserCertificate(address _wallet) public view returns (uint256[] memory){
        return mapUserCertificate[_wallet];
    }





}