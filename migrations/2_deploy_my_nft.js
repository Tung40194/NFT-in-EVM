const my_nft = artifacts.require("myNFT");

module.exports = function (deployer) {
  deployer.deploy(my_nft, "boredOak", "BOK", 100);
};
