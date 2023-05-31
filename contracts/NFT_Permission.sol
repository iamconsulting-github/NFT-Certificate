// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

pragma solidity ^0.8.7;

interface InterfaceNFTPermission {
    function checkAdminRole(address account) external view returns (bool);
    function checkMinterRole(address account) external view returns (bool);
    function checkBurnerRole(address account) external view returns (bool);
    function checkTransferRole(address account) external view returns (bool);
    function checkAccessRole(address account) external view returns (bool);
    function checkTokenAccessRole(address account, string memory _role) external view returns (bool);
    function getAddressRole(address account) external view returns (string memory);
}


contract NFTPermission is Initializable, AccessControlUpgradeable, InterfaceNFTPermission{

    struct TokenAccessRole {
        string permission;
        bool accountExist;
    }

    string[] public roles;

    bytes32 private constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 private constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 private constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _admin) initializer public {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(BURNER_ROLE, _admin);
        _grantRole(TRANSFER_ROLE, _admin);
        _grantRole(MINTER_ROLE, _admin);
        tokenAccessRoleAccountExist[_admin].permission = "DEFAULT ADMIN";
        tokenAccessRoleAccountExist[_admin].accountExist = true;
        roles.push("DEFAULT ADMIN");
    }


    // walletAddress => TokenAccessRole
    mapping(address => TokenAccessRole) public tokenAccessRoleAccountExist;
    mapping(string => bool) public mapRoleExist;

    //Permission
    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Require admin role.");
        _;
    }

    function listRole() public view returns(string[] memory) {
        return roles;
    }

    function setTokenAccessRole(address account, string memory role) public onlyAdmin
    {
        require(!tokenAccessRoleAccountExist[account].accountExist,"Account already exists.");

        grantRole(keccak256(abi.encodePacked(role)),account);
        grantRole(MINTER_ROLE,account);
        grantRole(BURNER_ROLE,account);
        grantRole(TRANSFER_ROLE,account);

        if(!mapRoleExist[role]){
            roles.push(role);
        }

        mapRoleExist[role] = true;
        tokenAccessRoleAccountExist[account].accountExist = true;
        tokenAccessRoleAccountExist[account].permission = role;
    }

    function revokeTokenAccessRole(address account) public onlyAdmin
    {
        require(tokenAccessRoleAccountExist[account].accountExist,"Account isn't exist.");
        require(!hasRole(DEFAULT_ADMIN_ROLE,account), "Can't revoke admin role.");
        revokeRole(keccak256(abi.encodePacked(tokenAccessRoleAccountExist[account].permission)),account);
        revokeRole(MINTER_ROLE,account);
        revokeRole(BURNER_ROLE,account);
        revokeRole(TRANSFER_ROLE,account);
        delete tokenAccessRoleAccountExist[account];
    }

    function checkAdminRole(address account) external view override returns (bool){
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    function checkMinterRole(address account) external view override returns (bool){
        return hasRole(MINTER_ROLE, account);
    }

    function checkBurnerRole(address account) external view override returns (bool){
        return hasRole(BURNER_ROLE, account);
    }

    function checkTransferRole(address account) external view override returns (bool){
        return hasRole(TRANSFER_ROLE, account);
    }

    function checkAccessRole(address account) external view override returns (bool){
        return tokenAccessRoleAccountExist[account].accountExist;
    }

    function checkTokenAccessRole(address account, string memory _role) external view override returns (bool){
        return hasRole(keccak256(abi.encodePacked(_role)), account);
    }

    function getAddressRole(address account) external view override returns (string memory){
        return tokenAccessRoleAccountExist[account].permission;
    }




}