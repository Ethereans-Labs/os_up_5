// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

import "@ethereansos/ethcomputationalorgs/contracts/base/model/ITreasuryManager.sol";
import { TransferUtilities } from "@ethereansos/swissknife/contracts/lib/GeneralUtilities.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

abstract contract HardCabledInfo {

    bytes32 private immutable _label;
    bytes32 private immutable _uri0;
    bytes32 private immutable _uri1;
    bytes32 private immutable _uri2;
    bytes32 private immutable _uri3;
    bytes32 private immutable _uri4;

    constructor(bytes32[] memory strings) {
        _label = strings[0];
        _uri0 = strings[1];
        _uri1 = strings[2];
        _uri2 = strings[3];
        _uri3 = strings[4];
        _uri4 = strings[5];
    }

    function LABEL() external view returns(string memory) {
        return _asString(_label);
    }

    function uri() external view returns(string memory) {
        return string(abi.encodePacked(
            _asString(_uri0),
            _asString(_uri1),
            _asString(_uri2),
            _asString(_uri3),
            _asString(_uri4)
        ));
    }

    function _asString(bytes32 value) private pure returns (string memory) {
        uint8 i = 0;
        while(i < 32 && value[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && value[i] != 0; i++) {
            bytesArray[i] = value[i];
        }
        return string(bytesArray);
    }
}

abstract contract LazyInitCapableHardCabledInfo is HardCabledInfo {

    address private _initializer;

    constructor(bytes32[] memory strings, bytes memory lazyInitData) HardCabledInfo(strings) {
        if(lazyInitData.length != 0) {
            __lazyInit(lazyInitData);
        }
    }

    function lazyInit(bytes memory lazyInitData) external returns(bytes memory lazyInitResponseData) {
        return __lazyInit(lazyInitData);
    }

    function initializer() external view returns(address) {
        return _initializer;
    }

    function __lazyInit(bytes memory lazyInitData) private returns(bytes memory lazyInitResponseData) {
        require(_initializer == address(0));
        _initializer = msg.sender;
        return _lazyInit(lazyInitData);
    }

    function _lazyInit(bytes memory lazyInitData) internal virtual returns(bytes memory lazyInitResponseData);
}

contract TransferManagerProposal is LazyInitCapableHardCabledInfo {
    using TransferUtilities for address;

    uint256 public constant ONE_HUNDRED = 1e18;

    uint256 public maxPercentagePerToken;

    string public additionalUri;
    address public treasuryManagerAddress;
    ITreasuryManager.TransferEntry[] private _entries;

    constructor(bytes32[] memory strings, bytes memory lazyInitData) LazyInitCapableHardCabledInfo(strings, lazyInitData) {}

    function _lazyInit(bytes memory lazyInitData) internal virtual override returns(bytes memory lazyInitResponseData) {
        (lazyInitData, lazyInitResponseData) = abi.decode(lazyInitData, (bytes, bytes));
        maxPercentagePerToken = abi.decode(lazyInitData, (uint256));
        maxPercentagePerToken = maxPercentagePerToken == 0 || maxPercentagePerToken > ONE_HUNDRED ? ONE_HUNDRED : maxPercentagePerToken;
        ITreasuryManager.TransferEntry[] memory __entries;
        (additionalUri, treasuryManagerAddress, __entries) = abi.decode(lazyInitResponseData, (string, address, ITreasuryManager.TransferEntry[]));
        require(treasuryManagerAddress != address(0), "zero");
        for(uint256 i = 0; i < __entries.length; i++) {
            _entries.push(__entries[i]);
        }

        lazyInitResponseData = "";
    }

    function entries() external view returns (ITreasuryManager.TransferEntry[] memory) {
        return _entries;
    }

    function execute(bytes32) external {
        (ITreasuryManager.TransferEntry[] memory __entries, address _treasuryManagerAddress) = (_entries, treasuryManagerAddress);
        _ensure(__entries, _treasuryManagerAddress);
        ITreasuryManager(_treasuryManagerAddress).batchTransfer(__entries);
    }

    function _ensure(ITreasuryManager.TransferEntry[] memory __entries, address _treasuryManagerAddress) private {
        _collect(__entries);
        uint256 percentage = maxPercentagePerToken;
        for(uint256 i = 0; i < _tokenAddresses.length; i++) {
            address tokenAddress = _tokenAddresses[i];
            uint256[] memory ids = _ids[tokenAddress];
            uint256[] memory balances;
            if(tokenAddress == address(0)) {
                balances = new uint256[](ids.length);
                for(uint256 z = 0; z < ids.length; z++) {
                    balances[z] = address(uint160(ids[z])).balanceOf(_treasuryManagerAddress);
                }
            } else {
                address[] memory accounts = new address[](ids.length);
                for(uint256 z = 0; z < ids.length; z++) {
                    accounts[z] = _treasuryManagerAddress;
                }
                balances = IERC1155(tokenAddress).balanceOfBatch(accounts, ids);
            }
            for(uint256 z = 0; z < ids.length; z++) {
                uint256 id = ids[z];
                uint256 balance = balances[z];
                uint256 value = _amounts[tokenAddress][id];
                require(balance > 0, "balance");
                require(value <= balance, "value");
                uint256 valueInPercentage = _calculatePercentage(balance, percentage);
                require(valueInPercentage == 0 || value <= valueInPercentage, "percentage");
                delete _amounts[tokenAddress][id];
            }
            delete _ids[tokenAddress];
        }
        delete _tokenAddresses;
    }

    address[] private _tokenAddresses;
    mapping(address => uint256[]) private _ids;
    mapping(address => mapping(uint256 => uint256)) private _amounts;

    function _collect(ITreasuryManager.TransferEntry[] memory __entries) private {
        for(uint256 i = 0; i < __entries.length; i++) {
            ITreasuryManager.TransferEntry memory transferEntry = __entries[i];
            if(transferEntry.values.length == 0) {
                continue;
            }
            address tokenAddress = transferEntry.token;
            for(uint256 z = 0; z < transferEntry.objectIds.length; z++) {
                uint256 value = transferEntry.values[z];
                if(value == 0) {
                    continue;
                }
                uint256 objectId = transferEntry.objectIds[z];
                if(_ids[tokenAddress].length == 0) {
                    _tokenAddresses.push(tokenAddress);
                }
                if(_amounts[tokenAddress][objectId] == 0) {
                    _ids[tokenAddress].push(objectId);
                }
                _amounts[tokenAddress][objectId] += value;
            }
        }
    }

    function _calculatePercentage(uint256 totalSupply, uint256 percentage) private pure returns (uint256) {
        return (totalSupply * ((percentage * 1e18) / ONE_HUNDRED)) / 1e18;
    }
}

contract EthereansOSTransferManagerProposal is TransferManagerProposal {

    uint256 public constant MAX_PERCENTAGE_PER_TOKEN = 5e17;

    constructor(bytes32[] memory strings, bytes memory lazyInitData) TransferManagerProposal(strings, lazyInitData) {}

    function _lazyInit(bytes memory lazyInitData) internal override returns(bytes memory lazyInitResponseData) {
        (, lazyInitData) = abi.decode(lazyInitData, (string, bytes));
        return super._lazyInit(abi.encode(abi.encode(MAX_PERCENTAGE_PER_TOKEN), lazyInitData));
    }
}