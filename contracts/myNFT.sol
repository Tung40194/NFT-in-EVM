
// contracts/myNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ERC721 is Context, ERC165, ERC2981, IERC721, IERC721Metadata, IERC721Enumerable {
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using Strings for uint256;
    using SafeMath for uint256;

    // Equals to `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    // which can be also obtained as `IERC721Receiver(0).onERC721Received.selector`
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    // Mapping from holder address to their (enumerable) set of owned tokens
    mapping (address => EnumerableSet.UintSet) private _holderTokens;

    // Enumerable mapping from token ids to their owners
    EnumerableMap.UintToAddressMap private _tokenOwners;

    // Mapping from token ID to approved address
    mapping (uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping (address => mapping (address => bool)) private _operatorApprovals;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Optional mapping for token URIs
    mapping (uint256 => string) private _tokenURIs;

    // Base URI
    string private _base_URI;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor (string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    // Interface function definition section.

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        // _tokenOwners are indexed by tokenIds, so .length() returns the number of tokenIds
        return _tokenOwners.length();
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        return _holderTokens[owner].at(index);
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        (uint256 tokenId, ) = _tokenOwners.at(index);
        return tokenId;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(base, tokenId.toString()));
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _holderTokens[owner].length();
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        return _tokenOwners.get(tokenId, "ERC721: owner query for nonexistent token");
    }
    
    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(_msgSender() == owner || ERC721.isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(operator != _msgSender(), "ERC721: approve to caller");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     * override function support interface - showing what kind of interface this contract supports
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165, ERC2981) returns (bool) {
        return (super.supportsInterface(interfaceId)
                || interfaceId == type(IERC2981).interfaceId
                || interfaceId == type(IERC721).interfaceId
                || interfaceId == type(IERC721Metadata).interfaceId
                || interfaceId == type(IERC721Enumerable).interfaceId);
    }

    // None interface & custom helper functions section.
    
    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     d*
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(address to, uint256 tokenId, bytes memory _data) internal virtual {
        _mint(to, tokenId);
        require(_checkOnERC721Received(address(0), to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
     
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _holderTokens[to].add(tokenId);

        _tokenOwners.set(tokenId, to);

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) private returns (bool) {
        if (!to.isContract()) {
            return true;
        }
        bytes memory returndata = to.functionCall(abi.encodeWithSelector(
            IERC721Receiver(to).onERC721Received.selector,
            _msgSender(),
            from,
            tokenId,
            _data
        ), "ERC721: transfer to non ERC721Receiver implementer");
        bytes4 retval = abi.decode(returndata, (bytes4));
        return (retval == _ERC721_RECEIVED);
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _tokenOwners.contains(tokenId);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || ERC721.isApprovedForAll(owner, spender));
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on _msgSender().
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own"); // internal owner
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);

        _tokenOwners.set(tokenId, to);

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId); // internal owner
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
    * @dev Returns the base URI set via {_setBaseURI}. This will be
    * automatically added as a prefix in {tokenURI} to each token's URI, or
    * to the token ID if no specific URI is set for that token ID.
    */
    function _baseURI() public view virtual returns (string memory) {
        return _base_URI;
    }

    /**
     * @dev Internal function to set the base URI for all token IDs. It is
     * automatically added as a prefix to the value returned in {tokenURI},
     * or to the token ID if {tokenURI} is empty.
     */
    function _setBaseURI(string memory baseURI_) internal virtual {
        _base_URI = baseURI_;
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }
}

// main contract to handle NFT generation & management
contract myNFT is ERC721, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    // private counter for making of token ID
    Counters.Counter private _tokenIdTracker;

    // Maximum NFT
    uint256 public MAX_NFT;

    // Maximum NFT can be minted each time
    uint public constant maxNFTEachMinting = 10;

    // price per NFT in Ether
    uint256 public constant pricePerNFTinEther = 0.01 ether;

    // price per NFT in token X
    uint256 public constant pricePerNFTinTokenX = 100;

    // whitelist lock flag
    bool public whitelistModeLock = false;

    // change minting mode: whitelist or free?
    enum mintingMode{   etherPurchased, 
                        whitelistBased, 
                        tokenXPurchased }
    mintingMode public mintMode = mintingMode.etherPurchased;

    // map user address to the number of token can be minted
    mapping(address => uint256) public _whiteList;

    // todo: change contract address that manage the token we want.
    address private erc20ContractAddress = 0x61175b02C97c13185ad10de68498b9874a7ce4a1;

    // constructor sets max supply
    constructor(string memory name, string memory symbol, uint256 maxNftSupply) ERC721(name, symbol) {
        MAX_NFT = maxNftSupply;
    }

    // fallback function to receive Ether
    fallback() external payable {}

     // receive function to receive Ether
    receive() external payable {}

    // check Ether balance of this contract
    function getEtherBalance() public view returns (uint) {
        return address(this).balance;
    }

    // check tokenX balance of this contract
    function getTokenXBalance() public view returns (uint) {
        ERC20 erc20instance = ERC20(erc20ContractAddress);
        return erc20instance.balanceOf(address(this));
    }

    // withdraw ETH to the owner of this contract
    function withdrawETH(uint256 amount) external onlyOwner {
        require(amount < address(this).balance, "Over withdrawal");
        payable(owner()).transfer(amount);
    }

    // withdraw tokenX
    function withdrawTokenX(uint256 amount) external onlyOwner {
        ERC20 erc20instance = ERC20(erc20ContractAddress);
        uint256 balance = erc20instance.balanceOf(address(this));
        require(amount < balance, "Over withdrawn");
        address service_provider = owner();
        // transfer() will move tokenX from the _msgSender() - which is this contract - to the owner.
        erc20instance.transfer(service_provider, amount);
    }

    //modifier that helps check to see if the user has a specific erc20 token
    modifier hasTheXToken(address user) {
        ERC20 erc20instance = ERC20(erc20ContractAddress);
        uint balance = erc20instance.balanceOf(user);
        require((balance > 0), "Qualifications don't meet: token X");
        _;
    }

    // set base URI for the NFT
    function setBaseURI(string memory baseURI) external onlyOwner {
        _setBaseURI(baseURI);
    }

    // set token URI for the NFT
    function setTokenURI(uint256 tokenId, string memory _tokenURI) external onlyOwner{
        _setTokenURI(tokenId, _tokenURI);
    }

    /**
     * @dev set minting mode
     * 0: style default, send Ether to mint
     * 1: whitelist, send Ether to mint
     * 2: send a specific erc20 token to mint
     */
    function setMintingMode(uint mode) public {
        // TODO: improve when mode doesn't belong to (0,2)
        require(mintMode != mintingMode(mode), "Current minting mode is already set");
        require(whitelistModeLock == false, "Whitelist minting hasn't taken place or finished");
        mintMode = mintingMode(mode);
    }

    // Set up white list
    /**FIXED:
     * set whitelist may get aligned with MAX_NFT, but if other mintings happen and push the boundary whitelist has set, 
     * when whitelist minting happens it exceeds MAX_NFT.
     * -> Add whitelistModeLock flag to make sure once whitelist's set, 
     * it goes all the way to the end of minting before other mintings take place
    */
    function setWhiteList(address[] calldata addresses, uint8 numAllowedToMint) external onlyOwner {
        require(totalSupply().add(addresses.length.mul(numAllowedToMint)) < MAX_NFT, "The total number of NFT exceeds MAX_NFT");
        for (uint256 i = 0; i < addresses.length; i.add(1)) {
            _whiteList[addresses[i]] = numAllowedToMint;
        }
        setMintingMode(uint256(mintingMode.whitelistBased));
        whitelistModeLock = true;
    }

    // Helper check to see how many NFT left for user to mint
    function numAvailableToMint(address addr) external view returns (uint256) {
        return _whiteList[addr];
    }

    /**
     * procedure:
     * 1) user approves this contract to spend an amount of their tokenX
     * 2) User calls this function to inform about the transaction info
     * 3) This contract spends their token and send the token to itself
     *
     * This way this contract gets to know the exact number of token sent from user
    */
    function TokenXPurchasedMint(uint8 numberOfNFTTokens) external hasTheXToken(_msgSender()) {
        require((mintMode == mintingMode.tokenXPurchased), "Unmatched minting mode! Please reset minting mode by setMintingMode()");
        ERC20 erc20instance = ERC20(erc20ContractAddress);
        uint256 tokenXAllowance = erc20instance.allowance(_msgSender(), address(this));
        require (tokenXAllowance > 0, "User has not approved this contract to spend their token");
        // send token to itself
        erc20instance.transferFrom(_msgSender(), address(this), tokenXAllowance);

        require(numberOfNFTTokens <= maxNFTEachMinting, "Can only mint maximally 10 tokens at a time");
        require(totalSupply().add(numberOfNFTTokens) <= MAX_NFT, "NFT token number exceeded");
        require(pricePerNFTinTokenX.mul(numberOfNFTTokens) <= tokenXAllowance, "The amount of token X sent doesn't meet tokenX-based proce calculated");

        for (uint256 i = 0; i < numberOfNFTTokens; i.add(1)) {
            _tokenIdTracker.increment();
            _safeMint(_msgSender(), _tokenIdTracker.current());
        }
    }

    // Mint NFT based on whitelist
    function whiteListBasedMint(uint8 numberOfNFTTokens) external payable {
        require((mintMode == mintingMode.whitelistBased), "Unmatched minting mode! Please reset minting mode by setMintingMode()");
        require(numberOfNFTTokens <= _whiteList[_msgSender()], "Exceeded max available to claim");
        require(numberOfNFTTokens <= maxNFTEachMinting, "Can only mint maximally 10 tokens at a time");
        require(pricePerNFTinEther.mul(numberOfNFTTokens) <= msg.value, "Ether value sent is not sufficient");

        _whiteList[_msgSender()] = _whiteList[_msgSender()].sub(numberOfNFTTokens);
        for (uint256 i = 0; i < numberOfNFTTokens; i.add(1)) {
            _tokenIdTracker.increment();
            _safeMint(_msgSender(), _tokenIdTracker.current());
        }
        whitelistModeLock = false;
    }

    // Mint NFT
    function EtherPurchasedMint(uint numberOfNFTTokens) external payable {
        require((mintMode == mintingMode.etherPurchased), "Unmatched minting mode! Please reset minting mode by setMintingMode()");
        require(numberOfNFTTokens <= maxNFTEachMinting, "Can only mint maximally 10 tokens at a time");
        require(totalSupply().add(numberOfNFTTokens) <= MAX_NFT, "token number exceeded");
        require(pricePerNFTinEther.mul(numberOfNFTTokens) <= msg.value, "Ether value sent is not sufficient");

        for(uint i = 0; i < numberOfNFTTokens; i.add(1)) {
            _tokenIdTracker.increment();
            _safeMint(_msgSender(), _tokenIdTracker.current());
        }
    }
}