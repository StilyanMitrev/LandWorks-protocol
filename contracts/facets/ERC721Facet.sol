// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../interfaces/IERC721Facet.sol";
import "../interfaces/IERC721Consumable.sol";
import "../libraries/LibOwnership.sol";
import "../libraries/LibERC721.sol";
import "../shared/RentPayout.sol";

contract ERC721Facet is IERC721Facet, IERC721Consumable, RentPayout {
    using Strings for uint256;

    /// @notice Initialises the ERC721's name, symbol and base URI.
    /// @param _name The target name
    /// @param _symbol The target symbol
    /// @param _baseURI The target base URI
    function initERC721(
        string memory _name,
        string memory _symbol,
        string memory _baseURI
    ) external {
        LibERC721.ERC721Storage storage erc721 = LibERC721.erc721Storage();
        require(!erc721.initialized, "ERC721 Storage already initialized");

        erc721.initialized = true;
        erc721.name = _name;
        erc721.symbol = _symbol;
        erc721.baseURI = _baseURI;
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view returns (uint256) {
        return LibERC721.balanceOf(owner);
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view returns (address) {
        return LibERC721.ownerOf(tokenId);
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view returns (string memory) {
        return LibERC721.erc721Storage().name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view returns (string memory) {
        return LibERC721.erc721Storage().symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(
            LibERC721.exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory base = ERC721Facet.baseURI();
        return
            bytes(base).length > 0
                ? string(abi.encodePacked(base, tokenId.toString()))
                : "";
    }

    /**
     * @dev Returns the base URI.
     */
    function baseURI() public view returns (string memory) {
        return LibERC721.erc721Storage().baseURI;
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view returns (uint256) {
        return LibERC721.erc721Storage().allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            index < balanceOf(owner),
            "ERC721Enumerable: owner index out of bounds"
        );
        return LibERC721.erc721Storage().ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            index < totalSupply(),
            "ERC721Enumerable: global index out of bounds"
        );
        return LibERC721.erc721Storage().allTokens[index];
    }

    /**
     * @dev Sets the base URI.
     * Token URIs will be autogenerated based on `baseURI` and their token IDs.
     * See {ERC721Facet-tokenURI}.
     *
     * Requirements:
     *
     * - The caller must be the owner of the contract.
     */
    function setBaseURI(string calldata _baseURI) public {
        LibOwnership.enforceIsContractOwner();

        LibERC721.erc721Storage().baseURI = _baseURI;
        emit SetBaseURI(_baseURI);
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public {
        address owner = ERC721Facet.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "ERC721: approve caller is not owner nor approved for all"
        );

        LibERC721.approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view returns (address) {
        return LibERC721.getApproved(tokenId);
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) external {
        require(operator != msg.sender, "ERC721: approve to caller");

        LibERC721.erc721Storage().operatorApprovals[msg.sender][
            operator
        ] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        returns (bool)
    {
        return LibERC721.isApprovedForAll(owner, operator);
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payout(tokenId) {
        //solhint-disable-next-line max-line-length
        require(
            LibERC721.isApprovedOrOwner(msg.sender, tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );

        LibERC721.transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public payout(tokenId) {
        require(
            LibERC721.isApprovedOrOwner(msg.sender, tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );
        LibERC721.safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev See {IERC721Consumable-changeConsumer}
     */
    function changeConsumer(address consumer, uint256 tokenId) public {
        require(
            LibERC721.isApprovedOrOwner(msg.sender, tokenId),
            "ERC721Consumer: change consumer caller is not owner nor approved"
        );

        LibERC721.changeConsumer(ownerOf(tokenId), consumer, tokenId);
    }

    /**
     * @dev See {IERC721Consumable-consumerOf}
     */
    function consumerOf(uint256 tokenId) public view returns (address) {
        return LibERC721.consumerOf(tokenId);
    }
}
