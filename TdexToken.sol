// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

/**
 * @dev Context variant with ERC2771 support.
 */
abstract contract ERC2771Context is Context {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private _trustedForwarder;

    function _setTrustedForwarder(address trustedForwarder) internal {
        _trustedForwarder = trustedForwarder;
    } 

    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return forwarder == _trustedForwarder;
    }

    modifier onlyTrustedForwarder(){
        require(msg.sender == _trustedForwarder, "Ownable: caller is not the TrustedForwarder");
        _;
    }

    function _msgSender() internal view virtual override returns (address sender) {
        if (isTrustedForwarder(msg.sender) && msg.data.length >= 20) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender) && msg.data.length >= 20) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }
}

contract TdexToken is ERC2771Context, ERC20, Ownable {

    uint256 private _totalBridgtSupply;
    address private _operator;
    address private _exchequer;

    mapping(address => bool) private _admins;
    mapping(address => bool) private _bridgeAdmins;
    mapping(address => bool) private _limitFrom;
    mapping(address => bool) private _limitTo;

    constructor() ERC20("Tdex Token", "TT") {
        setOperator(_msgSender());
    }

    modifier onlyOperator() {
        require(_operator == _msgSender(), "Ownable: caller is not the operator");
        _;
    }

    function setOperator(address operator) public onlyOwner {
        _operator = operator;
    }

    function setTrustedForwarder(address trustedForwarder) public onlyOwner {
        _setTrustedForwarder(trustedForwarder);
    }

    function setBridgeAdmin(address account, bool isAdmin_) public onlyOwner {
        _bridgeAdmins[account] = isAdmin_;
        if (isAdmin_ == false)
        {
            delete _bridgeAdmins[account];
        }
    }

    function isBridgeAdmin(address account) public view returns(bool) {
        return _bridgeAdmins[account];
    }

    modifier onlyBridgeAdmin() {
        require(_bridgeAdmins[_msgSender()] == true, "Ownable: caller is not the bridgeAdmins");
        _;
    }

    function totalBridgtSupply() public view returns (uint256) {
        return _totalBridgtSupply;
    }

    function mint(address account, uint256 amount) public onlyOperator {
        _mint(account, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function bridgeMint(address account, uint256 amount) public onlyBridgeAdmin {
        require(_totalBridgtSupply >= amount, "Not to exceed bridgeMint");
        _mint(account, amount);
        _totalBridgtSupply -= amount;
    }

    function bridgeBurn(uint256 amount) public onlyBridgeAdmin {
        _burn(msg.sender, amount);
        _totalBridgtSupply += amount;
    }

    function setExchequer(address exchequer) public onlyOwner {
        _exchequer = exchequer;
    }

    function setAdmin(address account, bool _isAdmin) public onlyOwner {
        _admins[account] = _isAdmin;
        if (_isAdmin == false)
        {
            delete _admins[account];
        }
    }

    function isAdmin(address account) public view returns(bool) {
        return _admins[account];
    }

    modifier onlyAdmin() {
        require(_admins[_msgSender()] == true, "Ownable: caller is not the administrator");
        _;
    }

    function setLimitFrom(address account, bool isNotFrom) public onlyAdmin {
        _limitFrom[account] = isNotFrom;
        if (isNotFrom == false)
        {
            delete _limitFrom[account];
        }
    }

    function inLimitFrom(address account) public view returns (bool) {
        return _limitFrom[account];
    }

    function setLimitTo(address account, bool isNotTo) public onlyAdmin {
        _limitTo[account] = true;
        if (isNotTo == false)
        {
            delete _limitTo[account];
        }
    }

    function inLimitTo(address account) public view returns (bool) {
        return _limitTo[account];
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal view override {
        if (totalSupply() > 0)
        {
            require(this.inLimitFrom(from) == false, "ERC20: no transfer out");
            require(this.inLimitTo(to) == false, "ERC20: no transfer in");
            amount;
        }
    }

    function paymentGas(address __from, uint256 __gas) public onlyTrustedForwarder {
        _transfer(__from, _exchequer, __gas);
    }

    function _msgSender() internal view virtual override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view virtual override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }
}
