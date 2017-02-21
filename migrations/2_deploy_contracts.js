module.exports = function(deployer) {
  deployer.autolink();
  deployer.deploy(Numeraire, 150000000000000, 0);
};
