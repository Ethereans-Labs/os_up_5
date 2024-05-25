var fs = require('fs');
var path = require('path');
var keccak = require('keccak');
var { VOID_ETHEREUM_ADDRESS, VOID_BYTES32, blockchainCall, compile, deployContract, abi, MAX_UINT256, web3Utils, fromDecimals, toDecimals } = require('@ethereansos/multiverse');

var additionalData = { from : web3.currentProvider.knowledgeBase.fromAddress };

module.exports = async function run() {
}

module.exports.test = async function test() {
    var IERC20 = await compile('@openzeppelin/contracts/token/ERC20/IERC20.sol');
    var os = new web3.eth.Contract(IERC20.abi, "0x6100dd79fCAA88420750DceE3F735d168aBcB771");
    var accounts = [
        "0x3CD8adf058b068e6F5FeB30cc6BB1268a269429e",
        "0x47f71198DBdeedFb624E427671A6dab54006e4bf",
        "0x10B2E5DF4F5ffaB4f98BD625933185e455Ddd1C9",
        "0xe349b59813a28f1AB0Bcd8483fd0EDaD2A638728",
        "0x573cD3D5f75b42AC50f2Ca7B734f03d254585B5f",
        "0x48ef89dE42F9C6bA81fF4f6abA78bc1Ca827c7AC"
    ];
    for(var from of accounts) {
        var balance = await os.methods.balanceOf(from).call();
        await blockchainCall(os.methods.transfer, web3.currentProvider.knowledgeBase.fromAddress, balance, {from});
    }
}