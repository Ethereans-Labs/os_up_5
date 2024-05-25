// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

import "@ethereansos/ethcomputationalorgs/contracts/ext/delegationsManager/model/IDelegationsManager.sol";
import "@ethereansos/swissknife/contracts/generic/impl/LazyInitCapableElement.sol";
import "@ethereansos/ethcomputationalorgs/contracts/core/model/IOrganization.sol";
import "@ethereansos/ethcomputationalorgs/contracts/ext/subDAOsManager/model/ISubDAOsManager.sol";
import { TransferUtilities } from "@ethereansos/swissknife/contracts/lib/GeneralUtilities.sol";
import { Getters } from "@ethereansos/ethcomputationalorgs/contracts/base/lib/KnowledgeBase.sol";
import { Grimoire as ExtendedGrimoire, Getters as ExtendedGetters, Setters as ExtendedSetters } from "@ethereansos/ethcomputationalorgs/contracts/ext/lib/KnowledgeBase.sol";
import { Grimoire as EthereansGrimoire } from "@ethereansos/ethcomputationalorgs/contracts/ethereans/lib/KnowledgeBase.sol";

contract TemporaryDelegationsManager is IDelegationsManager, LazyInitCapableElement {
    using Getters for IOrganization;
    using ExtendedGetters for IOrganization;
    using ExtendedSetters for IOrganization;
    using TransferUtilities for address;

    address public owner;
    address public originalDelegationsManager;

    constructor(bytes memory lazyInitData) LazyInitCapableElement(lazyInitData) {}

    function _lazyInit(bytes memory lazyInitData) internal override returns (bytes memory) {
        (owner, originalDelegationsManager) = abi.decode(lazyInitData, (address, address));
        return "";
    }

    function _supportsInterface(bytes4 interfaceId) internal override view returns(bool) {
        return IDelegationsManager(originalDelegationsManager).supportsInterface(interfaceId);
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function setOwner(address newValue) external onlyOwner {
        owner = newValue;
    }

    function finalize(address finalComponent) external onlyOwner {
        address(0).safeTransfer(finalComponent, address(0).balanceOf(address(this)));
        IOrganization root = IOrganization(host);
        ISubDAOsManager subDAOsManager = root.subDAOsManager();
        subDAOsManager.submit(EthereansGrimoire.SUBDAO_KEY_ETHEREANSOS_V1, abi.encodeWithSelector(root.set.selector, IOrganization.Component(ExtendedGrimoire.COMPONENT_KEY_DELEGATIONS_MANAGER, finalComponent, false, true)), finalComponent);
        root.replaceDelegationsManager(finalComponent);
    }

    receive() external payable {
        address(0).safeTransfer(address(IOrganization(host).treasuryManager()), address(0).balanceOf(address(this)));
    }

    function split(address) external override {
        revert();
    }

    function supportedToken() external override view returns(address collection, uint256 objectId) {
        return IDelegationsManager(originalDelegationsManager).supportedToken();
    }

    function setSupportedToken(address, uint256) external override {
        revert();
    }

    function maxSize() external override view returns(uint256) {
        return IDelegationsManager(originalDelegationsManager).maxSize();
    }

    function setMaxSize(uint256) external override returns (uint256 oldValue) {
        revert();
    }

    function size() external override view returns (uint256) {
        return IDelegationsManager(originalDelegationsManager).size();
    }

    function list() external override view returns (DelegationData[] memory) {
        return IDelegationsManager(originalDelegationsManager).list();
    }

    function partialList(uint256 start, uint256 offset) external override view returns (DelegationData[] memory) {
        return IDelegationsManager(originalDelegationsManager).partialList(start, offset);
    }

    function listByAddresses(address[] calldata delegationAddresses) external override view returns (DelegationData[] memory) {
        return IDelegationsManager(originalDelegationsManager).listByAddresses(delegationAddresses);
    }

    function listByIndices(uint256[] calldata indices) external override view returns (DelegationData[] memory) {
        return IDelegationsManager(originalDelegationsManager).listByIndices(indices);
    }

    function exists(address delegationAddress) external override view returns(bool result, uint256 index, address treasuryOf) {
        return IDelegationsManager(originalDelegationsManager).exists(delegationAddress);
    }

    function treasuryOf(address delegationAddress) external override view returns(address treasuryAddress) {
        return IDelegationsManager(originalDelegationsManager).treasuryOf(delegationAddress);
    }

    function get(address delegationAddress) external override view returns(DelegationData memory) {
        return IDelegationsManager(originalDelegationsManager).get(delegationAddress);
    }

    function getByIndex(uint256 index) external override view returns(DelegationData memory) {
        return IDelegationsManager(originalDelegationsManager).getByIndex(index);
    }

    function set() external override {
        revert();
    }

    function remove(address[] calldata) external override returns(DelegationData[] memory) {
        revert();
    }

    function removeAll() external override {
        revert();
    }

    function executorRewardPercentage() external override view returns(uint256) {
        return IDelegationsManager(originalDelegationsManager).executorRewardPercentage();
    }

    function getSplit(address executorRewardReceiver) external override view returns (address[] memory receivers, uint256[] memory values) {
        return IDelegationsManager(originalDelegationsManager).getSplit(executorRewardReceiver);
    }

    function getSituation() external override view returns(address[] memory treasuries, uint256[] memory treasuryPercentages) {
        return IDelegationsManager(originalDelegationsManager).getSituation();
    }

    function factoryIsAllowed(address factoryAddress) external override view returns(bool) {
        return IDelegationsManager(originalDelegationsManager).factoryIsAllowed(factoryAddress);
    }

    function setFactoriesAllowed(address[] memory factoryAddresses, bool[] memory allowed) external override {
        revert();
    }

    function isBanned(address productAddress) external override view returns(bool) {
        return IDelegationsManager(originalDelegationsManager).isBanned(productAddress);
    }

    function ban(address[] memory productAddresses) external override {
        revert();
    }

    function isValid(address delegationAddress) external override view returns(bool) {
        return IDelegationsManager(originalDelegationsManager).isValid(delegationAddress);
    }

    function paidFor(address delegationAddress, address retriever) external override view returns(uint256 totalPaid, uint256 retrieverPaid) {
        return IDelegationsManager(originalDelegationsManager).paidFor(delegationAddress, retriever);
    }

    function payFor(address delegationAddress, uint256 amount, bytes memory permitSignature, address retriever) external override payable {
        revert();
    }

    function retirePayment(address delegationAddress, address receiver, bytes memory data) external override {
        revert();
    }

    function attachInsurance() external override view returns (uint256) {
        return IDelegationsManager(originalDelegationsManager).attachInsurance();
    }

    function setAttachInsurance(uint256 value) external override returns (uint256 oldValue) {
        revert();
    }
}