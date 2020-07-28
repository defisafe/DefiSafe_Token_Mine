const DefiSafeMine = artifacts.require("DefiSafeMine");
const ERC20Interface = artifacts.require("ERC20Interface");

module.exports = function(deployer) {
  deployer.deploy(DefiSafeMine);
  deployer.link(DefiSafeMine, ERC20Interface);
  deployer.deploy(ERC20Interface);
};
