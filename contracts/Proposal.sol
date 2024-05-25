// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

import "@ethereansos/ethcomputationalorgs/contracts/ext/subDAO/model/ISubDAO.sol";
import "@ethereansos/ethcomputationalorgs/contracts/base/model/IStateManager.sol";
import "@ethereansos/ethcomputationalorgs/contracts/ext/subDAOsManager/model/ISubDAOsManager.sol";
import { Grimoire, Getters, State } from "@ethereansos/ethcomputationalorgs/contracts/base/lib/KnowledgeBase.sol";
import { Grimoire as ExternalGrimoire, Getters as ExternalGetters } from "@ethereansos/ethcomputationalorgs/contracts/ext/lib/KnowledgeBase.sol";
import { Grimoire as EthereansGrimoire } from "@ethereansos/ethcomputationalorgs/contracts/ethereans/lib/KnowledgeBase.sol";
import { ComponentsGrimoire as EthereansComponentsGrimoire } from "@ethereansos/ethcomputationalorgs/contracts/ethereans/lib/KnowledgeBase.sol";

contract Proposal {
    using Getters for IOrganization;
    using Getters for ISubDAO;
    using State for IStateManager;
    using ExternalGetters for IOrganization;

    bytes32 private immutable MYSELF_KEY = keccak256(abi.encodePacked(address(this), block.number, tx.gasprice, block.coinbase, block.difficulty, msg.sender, block.timestamp));

    string public uri;

    address public temporaryDelegationsManagerAddress;
    ISubDAO.SubDAOProposalModel[] public additionalProposalModels;
    string public changeOSBurnAmountStateKey;
    uint256 public changeOSBurnAmountFirstValueIndex;

    struct ProposalConstructorArgs {
        string _uri;
        address _temporaryDelegationsManagerAddress;
        ISubDAO.SubDAOProposalModel[] _additionalProposalModels;
        string _changeOSBurnAmountStateKey;
        uint256 _changeOSBurnAmountFirstValueIndex;
    }
    
    constructor(ProposalConstructorArgs memory _args) {
        uri = _args._uri;
        temporaryDelegationsManagerAddress = _args._temporaryDelegationsManagerAddress;
        
        for(uint256 i = 0; i < _args._additionalProposalModels.length; i++) {
            additionalProposalModels.push(_args._additionalProposalModels[i]);
        }

        changeOSBurnAmountStateKey = _args._changeOSBurnAmountStateKey;
        changeOSBurnAmountFirstValueIndex = _args._changeOSBurnAmountFirstValueIndex;
    }

    function execute(bytes32) external {
        _setOSBurnInitialValueAndNewSubDAOProposalModels(_changeTreasuryHostAndMountManagers(IOrganization(ILazyInitCapableElement(msg.sender).host())));
    }

    function _changeTreasuryHostAndMountManagers(IOrganization root) private returns (ISubDAO subDAO) {

        IOrganization.Component[] memory components = new IOrganization.Component[](2);
        components[0] = IOrganization.Component({
            key : ExternalGrimoire.COMPONENT_KEY_DELEGATIONS_MANAGER,
            location : temporaryDelegationsManagerAddress,
            active : true,
            log : true
        });
        components[1] = IOrganization.Component({
            key : MYSELF_KEY,
            location : address(this),
            active : true,
            log : false
        });

        root.set(components[0]);

        ISubDAOsManager subDAOsManager = root.subDAOsManager();

        root.treasuryManager().setHost(address((subDAO = ISubDAO(subDAOsManager.get(EthereansGrimoire.SUBDAO_KEY_ETHEREANSOS_V1)))));

        subDAOsManager.submit(EthereansGrimoire.SUBDAO_KEY_ETHEREANSOS_V1, abi.encodeWithSelector(root.batchSet.selector, components), address(0));
    }

    function _setOSBurnInitialValueAndNewSubDAOProposalModels(ISubDAO subDAO) private {

        (, uint256 value) = abi.decode(additionalProposalModels[0].presetValues[changeOSBurnAmountFirstValueIndex], (string, uint256));
        subDAO.stateManager().setUint256(changeOSBurnAmountStateKey, value);

        ISubDAO.SubDAOProposalModel[] memory proposalModels = subDAO.proposalModels();

        ISubDAO.SubDAOProposalModel[] memory newProposalModels = new ISubDAO.SubDAOProposalModel[](proposalModels.length + 2);

        uint256 newI = 0;
        uint256 i;
        for(i = 0; i < 7; i++) {
            subDAO.setPresetValues(i, proposalModels[i].presetValues);
            (newProposalModels[newI++] = proposalModels[i]).presetProposals = new bytes32[](proposalModels[i].presetProposals.length);
        }

        newProposalModels[newI++] = additionalProposalModels[0];
        newProposalModels[newI++] = additionalProposalModels[1];

        newProposalModels[newI++] = proposalModels[proposalModels.length - 2];
        newProposalModels[newI++] = proposalModels[proposalModels.length - 1];

        subDAO.setProposalModels(newProposalModels);

        subDAO.set(IOrganization.Component({
            key : MYSELF_KEY,
            location : address(0),
            active : false,
            log : false
        }));
    }
}