var fs = require('fs');
var path = require('path');
var keccak = require('keccak');
var { VOID_ETHEREUM_ADDRESS, VOID_BYTES32, blockchainCall, compile, deployContract, abi, MAX_UINT256, web3Utils, fromDecimals, toDecimals } = require('@ethereansos/multiverse');

var additionalData = { from : web3.currentProvider.knowledgeBase.from };

var STATEMANAGER_ENTRY_NAME_DAO_FACTORY_OS_AMOUNT_TO_BURN_AT_CREATION = "daoFactoryOSAmountToBurnAtCreation";

async function deployTemporaryDelegationsManager() {
    var Organization = await compile('@ethereansos/ethcomputationalorgs/contracts/core/model/IOrganization');
    var organization = new web3.eth.Contract(Organization.abi, web3.currentProvider.knowledgeBase.ourDFO);
    var originalDelegationsManagerAddress = await blockchainCall(organization.methods.get, web3.currentProvider.knowledgeBase.grimoire.COMPONENT_KEY_DELEGATIONS_MANAGER);
    var host = await (new web3.eth.Contract(Organization.abi, originalDelegationsManagerAddress)).methods.host().call();

    var deployData = abi.encode(["address", "address"], [web3.currentProvider.knowledgeBase.fromAddress, originalDelegationsManagerAddress]);
    deployData = abi.encode(["address", "bytes"], [host, deployData]);

    var TemporaryDelegationsManager = await compile('TemporaryDelegationsManager');
    var temporaryDelegationsManager = await deployContract(new web3.eth.Contract(TemporaryDelegationsManager.abi), TemporaryDelegationsManager.bin, [deployData], additionalData);
    return temporaryDelegationsManager;
}

async function getProposalModels() {
    var response = await web3.eth.call({
        to : web3.currentProvider.knowledgeBase.ourSubDAO,
        data : web3Utils.sha3('proposalModels()').substring(0, 10)
    });
    var SubDAOProposalModel = {
        source: 'address',
        uri: 'string',
        isPreset: 'bool',
        presetValues: 'bytes[]',
        presetProposals: 'bytes32[]',
        creationRules: 'address',
        triggeringRules: 'address',
        votingRulesIndex: 'uint256',
        canTerminateAddresses: 'address[][]',
        validatorsAddresses: 'address[][]'
    };
    var result = decodeCallResponse(response, [{type : 'tuple[]', components : Object.entries(SubDAOProposalModel).map(it => ({ name : it[0], type : it[1]}))}])
    return result;
}

async function deployAndPrepareAdditionalProposalModels() {
    var proposalModels = await getProposalModels();
    var values = [2, 4, 6, 10, 13, 15].map(it => toDecimals(it, 18))
    var amountToBurnIPFSHash = 'QmNLiDxDZEPvnCEak9kBakF7MWn3YBaAgFXYcWks7MosBp';
    return [
        osAmountToBurnProposalModel(proposalModels[1].source, amountToBurnIPFSHash, STATEMANAGER_ENTRY_NAME_DAO_FACTORY_OS_AMOUNT_TO_BURN_AT_CREATION, values, proposalModels[1].validatorsAddresses[0]),
        await transferProposalModel(proposalModels[7].canTerminateAddresses, proposalModels[7].validatorsAddresses)
    ];
}

function osAmountToBurnProposalModel(source, uri, name, values, validatorContract) {
    return {
        source,
        uri : "ipfs://ipfs/" + uri,
        isPreset : true,
        presetValues : values.map(it => abi.encode(["string", "uint256"], [name, it])),
        presetProposals : [],
        creationRules : VOID_ETHEREUM_ADDRESS,
        triggeringRules : VOID_ETHEREUM_ADDRESS,
        votingRulesIndex : 0,
        canTerminateAddresses : [[]],
        validatorsAddresses : [validatorContract]
    };
}

async function transferProposalModel(canTerminateAddresses, validatorsAddresses) {
    var contract = await getHardCabledInfoContract("EthereansOSTransferManagerProposal", "EthereansOSTransferManagerProposal", "TRANSFER_MANAGER_V1", "ipfs://ipfs/QmQp4Z9iNcJ2oyFAM2Tn1NTzYBEfN4zNAF5smn1fbsruCe", true);
    return {
        source : contract.options.address,
        uri : "ipfs://ipfs/QmQp4Z9iNcJ2oyFAM2Tn1NTzYBEfN4zNAF5smn1fbsruCe",
        isPreset : false,
        presetValues : [],
        presetProposals : [],
        creationRules : VOID_ETHEREUM_ADDRESS,
        triggeringRules : VOID_ETHEREUM_ADDRESS,
        votingRulesIndex : 0,
        canTerminateAddresses : canTerminateAddresses,
        validatorsAddresses : validatorsAddresses
    };
}

function fillWithZeroes(data, limit) {
    limit = limit || 66
    data = data.startsWith('0x') ? data : ('0x' + data);
    while(data.length < limit) {
        data += '0';
    }
    return data;
}

async function getHardCabledInfoContract(location, name, LABEL, uri, isLazyInit) {
    var Contract = await compile(location, name);
    var strings = toBytes32Array(LABEL, uri);
    var args = [strings];
    isLazyInit && args.push('0x');
    return await deployContract(new web3.eth.Contract(Contract.abi), Contract.bin, args, additionalData);
}

function toBytes32Array(LABEL, uri) {
    var array = [
        fillWithZeroes(web3Utils.toHex(LABEL))
    ];
    uri = web3Utils.toHex(uri).substring(2);
    array.push(fillWithZeroes(uri.substring(0, 64)));
    uri = uri.substring(64);
    array.push(fillWithZeroes(uri.substring(0, 64)));
    uri = uri.substring(64);
    array.push(fillWithZeroes(uri.substring(0, 64)));
    uri = uri.substring(64);
    array.push(fillWithZeroes(uri.substring(0, 64)));
    uri = uri.substring(64);
    array.push(fillWithZeroes(uri.substring(0, 64)));
    return array;
}

function decodeCallResponse(response, outputs) {
    var types = recursiveOutput(outputs)
    if(response === '0x') {
      return types.length !== 1 ? null : types[0].toLowerCase().indexOf('[]') !== -1 ? [] : types[0].toLowerCase().indexOf('tuple') !== -1 ? null : types[0].toLowerCase() === 'bytes' ? '0x' : types[0].toLowerCase() === 'string' ? '' : types[0].toLowerCase() === 'bool' ? false : types[0].toLowerCase() === 'address' ? VOID_ETHEREUM_ADDRESS  : types[0].toLowerCase() === 'bytes32' ? VOID_BYTES32 : "0"
    }
    response = abi.decode(types, response)
    response = toStringRecursive(response)
    response = reduceRecursive(response, outputs)
    if(outputs.length === 1) {
      response = response[0]
    }
    return response
  }

  function recursiveOutput(outputs) {
    return outputs.map(it => it.components ? `tuple(${recursiveOutput(it.components).join(',')})${it.type.indexOf('[]') !== -1 ? '[]' : ''}`: it.type)
  }

  function toStringRecursive(outputs) {
    return outputs.map(it => Array.isArray(it) ? toStringRecursive(it) : it.toString())
  }

  function reduceRecursive(result, metadata) {
    return result.reduce((acc, it, i) => ({...acc, [i] : metadata[i].components ? metadata[i].type.indexOf('[]') !== -1 ? it.map(elem => reduceRecursive(elem, metadata[i].components)) : reduceRecursive(it, metadata[i].components) : it, [metadata[i].name || i] : metadata[i].components ? metadata[i].type.indexOf('[]') !== -1 ? it.map(elem => reduceRecursive(elem, metadata[i].components)) : reduceRecursive(it, metadata[i].components) : it}), {})
  }

async function generateProposalBytecode() {

    console.log("Generating Proposal Bytecode");

    var Proposal = await compile('Proposal');

    var proposalUri = 'ipfs://ipfs/QmfGaEHCpoqkFY1T7zSsCMQbFXkAnAWwppmpaqSkAD7RxV';

    var args = [{
        _uri: proposalUri,
        _temporaryDelegationsManagerAddress : (await deployTemporaryDelegationsManager()).options.address,
        _additionalProposalModels : await deployAndPrepareAdditionalProposalModels(),
        _changeOSBurnAmountStateKey : STATEMANAGER_ENTRY_NAME_DAO_FACTORY_OS_AMOUNT_TO_BURN_AT_CREATION,
        _changeOSBurnAmountFirstValueIndex : 1
    }];

    var proposalBytecode = new web3.eth.Contract(Proposal.abi).deploy({data : Proposal.bin, arguments: args}).encodeABI();

    return proposalBytecode;
}

async function propose(proposalBytecode) {
    console.log("Generating Proposal");

    var Organization = await compile('@ethereansos/ethcomputationalorgs/contracts/core/model/IOrganization');
    var organization = new web3.eth.Contract(Organization.abi, web3.currentProvider.knowledgeBase.ourDFO);

    var subDAO = new web3.eth.Contract(Organization.abi, web3.currentProvider.knowledgeBase.ourSubDAO);

    var proposalsManagerAddress = await blockchainCall(organization.methods.get, web3.currentProvider.knowledgeBase.grimoire.COMPONENT_KEY_PROPOSALS_MANAGER);
    var ProposalsManager = await compile('@ethereansos/ethcomputationalorgs/contracts/base/impl/ProposalsManager');
    var proposalsManager = new web3.eth.Contract(ProposalsManager.abi, proposalsManagerAddress);

    var treasuryManagerAddress = await blockchainCall(organization.methods.get, web3.currentProvider.knowledgeBase.grimoire.COMPONENT_KEY_TREASURY_MANAGER);

    var input = [{
        codes : [{
            location : VOID_ETHEREUM_ADDRESS,
            bytecode : proposalBytecode
        }],
        alsoTerminate : false
    }];

    await blockchainCall(proposalsManager.methods.batchCreate, input, { from : web3.currentProvider.knowledgeBase.from });

    const proposalId = await blockchainCall(proposalsManager.methods.lastProposalId);

    const proposalData = (await blockchainCall(proposalsManager.methods.list, [proposalId]))[0];

    return {
        subDAO,
        organization,
        proposalsManager,
        treasuryManagerAddress,
        proposalId,
        proposalData
    };
}

var result

module.exports = async function run() {

    result = await propose(await generateProposalBytecode());
    console.log("ProposalId", result.proposalId);
}