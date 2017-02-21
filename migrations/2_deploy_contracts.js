var Numeraire = artifacts.require("./contracts/Numeraire.sol");
var addresses = [10,5];
module.exports = function(deployer) {
  deployer.deploy(Numeraire, addresses, 2, 1500000000000000000000000);
};