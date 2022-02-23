# prerequisites:
- node: 16.14.0
- npm: 8.3.1
- truffle: 5.4.33
- openzeppelin: latest

# start up
- compile: `truffle compile`
- start node: `truffle develop`
- deploy: `truffle migrate`

# instantiating contract
- `let contract = await myNFT.deployed()`
- `contract.name()`