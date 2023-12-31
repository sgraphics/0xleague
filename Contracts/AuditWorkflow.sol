// SPDX-License-Identifier: UNLICENSED
// This smart contract code is proprietary.
// Unauthorized copying, modification, or distribution is strictly prohibited.
// For licensing inquiries or permissions, contact info@toolblox.net.
pragma solidity ^0.8.19;
interface IExternal0xleague_auditor_profile {
	function addScore(uint id, uint newScore) external returns (uint);
	function getStatus(uint id) external view returns (uint64);
	function getName(uint id) external view returns (string memory);
	function getAuditor(uint id) external view returns (address);
	function getTelegram(uint id) external view returns (string memory);
	function getScore(uint id) external view returns (uint);
	function getScoreCount(uint id) external view returns (uint64);
	function getImage(uint id) external view returns (string memory);
	function getDescription(uint id) external view returns (string memory);
	function getTwitter(uint id) external view returns (string memory);
	function getSignedNda(uint id) external view returns (string memory);
	function getNda() external view returns (string memory);
}
import "https://raw.githubusercontent.com/Ideevoog/Toolblox.Token/main/Contracts/WorkflowBase.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.3/contracts/access/Ownable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.3/contracts/token/ERC721/ERC721.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.3/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.3/contracts/security/ReentrancyGuard.sol";
import "https://raw.githubusercontent.com/Ideevoog/Toolblox.Token/main/Contracts/OwnerPausable.sol";
/*
	Toolblox smart-contract workflow: https://app.toolblox.net/summary/0xleague_audit_management
*/
contract AuditWorkflow  is WorkflowBase, Ownable, ERC721, ERC721Enumerable, ReentrancyGuard, OwnerPausable{
	struct Audit {
		uint id;
		uint64 status;
		string name;
		address client;
		address auditor;
		string gitCommit;
		string telegramId;
		string nda;
		uint price;
		string image;
		uint auditorId;
		string description;
	}
	bytes32 auditorFlowAddress = keccak256("0xleague_auditor_profile");
	mapping(uint => Audit) public items;
	address public token = 0x690000EF01deCE82d837B5fAa2719AE47b156697;
	function _assertOrAssignClient(Audit memory item) private view {
		address client = item.client;
		if (client != address(0))
		{
			require(_msgSender() == client, "Invalid Client");
			return;
		}
		item.client = _msgSender();
	}
	function _assertOrAssignAuditor(Audit memory item) private view {
		address auditor = item.auditor;
		if (auditor != address(0))
		{
			require(_msgSender() == auditor, "Invalid Auditor");
			return;
		}
		item.auditor = _msgSender();
	}
	constructor() ERC721("Audit - 0xLeague Audit Management", "AUDIT") {
		_transferOwnership(_msgSender());
		serviceLocator = IExternalServiceLocator(0xABD5F9cFB2C796Bbd1647023ee2BEA74B23bf672);
	}
	function setOwner(address _newOwner) public {
		transferOwnership(_newOwner);
	}
/*
	Available statuses:
	0 Requested (owner Client)
	1 Offered (owner Client)
	2 In progress (owner Auditor)
	3 Completed (owner Client)
	4 Reviewed (owner Client)
*/
	function _assertStatus(Audit memory item, uint64 status) private pure {
		require(item.status == status, "Cannot run Workflow action; unexpected status");
	}
	function getItem(uint256 id) public view returns (Audit memory) {
		Audit memory item = items[id];
		require(item.id == id, "Cannot find item with given id");
		return item;
	}
	function getLatest(uint256 cnt) public view returns(Audit[] memory) {
		uint256[] memory latestIds = getLatestIds(cnt);
		Audit[] memory latestItems = new Audit[](latestIds.length);
		for (uint256 i = 0; i < latestIds.length; i++) latestItems[i] = items[latestIds[i]];
		return latestItems;
	}
	function getPage(uint256 cursor, uint256 howMany) public view returns(Audit[] memory) {
		uint256[] memory ids = getPageIds(cursor, howMany);
		Audit[] memory result = new Audit[](ids.length);
		for (uint256 i = 0; i < ids.length; i++) result[i] = items[ids[i]];
		return result;
	}
	function getItemOwner(Audit memory item) private view returns (address itemOwner) {
				if (item.status == 0) {
			itemOwner = item.client;
		}
		else 		if (item.status == 1) {
			itemOwner = item.client;
		}
		else 		if (item.status == 2) {
			itemOwner = item.auditor;
		}
		else 		if (item.status == 3) {
			itemOwner = item.client;
		}
		else 		if (item.status == 4) {
			itemOwner = item.client;
		}
        else {
			itemOwner = address(this);
        }
        if (itemOwner == address(0))
        {
            itemOwner = address(this);
        }
	}
	
	mapping(uint => uint[]) public itemsByAuditorId;
	function getItemIdsByAuditorId(uint auditorId) public view returns (uint[] memory) {
		return itemsByAuditorId[auditorId];
	}
	function getItemsByAuditorId(uint auditorId) public view returns (Audit[] memory) {
		uint[] memory itemIds = getItemIdsByAuditorId(auditorId);
		Audit[] memory itemsToReturn = new Audit[](itemIds.length);
		for(uint256 i=0; i < itemIds.length; i++){
			itemsToReturn[i] = getItem(itemIds[i]);
		}
		return itemsToReturn;
	}
	function _setItemIdByAuditorId(uint oldForeignKey, uint newForeignKey, uint id) private {
		// If the old and new foreign keys are the same, no need to do anything
		if(oldForeignKey == newForeignKey) {
			return;
		}
		// If the old foreign key is not 0, remove the item from the old list
		if(oldForeignKey != 0) {
			removeFkMappingItem(itemsByAuditorId, oldForeignKey, id);
		}
		// If the new foreign key is not 0, add the item to the new list
		if(newForeignKey != 0) {
			addFkMappingItem(itemsByAuditorId, newForeignKey, id);
		}
	}
	function _afterTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal virtual override {
		super._afterTokenTransfer(from, to, firstTokenId, batchSize);
		if (from == to)
		{
			return;
		}
		Audit memory item = getItem(firstTokenId);
		if (item.status == 0) {
			item.client = to;
		}
		if (item.status == 1) {
			item.client = to;
		}
		if (item.status == 2) {
			item.auditor = to;
		}
		if (item.status == 3) {
			item.client = to;
		}
		if (item.status == 4) {
			item.client = to;
		}
	}
	function supportsInterface(bytes4 interfaceId) public view override(ERC721,ERC721Enumerable) returns (bool) {
		return super.supportsInterface(interfaceId);
	}
	function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal virtual override (ERC721,ERC721Enumerable) {
		super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
	}
	function _baseURI() internal view virtual override returns (string memory) {
		return "https://nft.toolblox.net/api/metadata?workflowId=0xleague_audit_management&id=";
	}
	function getId(uint id) public view returns (uint){
		return getItem(id).id;
	}
	function getStatus(uint id) public view returns (uint64){
		return getItem(id).status;
	}
	function getName(uint id) public view returns (string memory){
		return getItem(id).name;
	}
	function getClient(uint id) public view returns (address){
		return getItem(id).client;
	}
	function getAuditor(uint id) public view returns (address){
		return getItem(id).auditor;
	}
	function getGitCommit(uint id) public view returns (string memory){
		return getItem(id).gitCommit;
	}
	function getTelegramId(uint id) public view returns (string memory){
		return getItem(id).telegramId;
	}
	function getNda(uint id) public view returns (string memory){
		return getItem(id).nda;
	}
	function getPrice(uint id) public view returns (uint){
		return getItem(id).price;
	}
	function getImage(uint id) public view returns (string memory){
		return getItem(id).image;
	}
	function getAuditorId(uint id) public view returns (uint){
		return getItem(id).auditorId;
	}
	function getDescription(uint id) public view returns (string memory){
		return getItem(id).description;
	}
/*
	### Transition: 'Request audit'
	This transition creates a new object and puts it into `Requested` state.
	
	#### Transition Parameters
	For this transition, the following parameters are required: 
	
	* `Auditor Id` (Other flow id)
	* `Git commit` (Text)
	* `Telegram id` (Text)
	* `Name` (Text)
	* `Client` (User)
	* `Auditor` (User)
	* `NDA` (Blob)
	
	#### Access Restrictions
	Access is exclusively provided to the workflow at URL: `0xleague_auditor_profile`.
	
	#### Checks and updates
	The following properties will be updated on blockchain:
	
	* `Auditor Id` (Fk)
	* `Git commit` (String)
	* `Telegram id` (String)
	* `Name` (String)
	* `Client` (Address)
	* `Auditor` (Address)
	* `NDA` (Blob)
*/
	function requestAudit(uint auditorId,string calldata gitCommit,string calldata telegramId,string calldata name,address client,address auditor,string calldata nda) external whenNotPaused nonReentrant returns (uint256) {
		uint256 id = _getNextId();
		Audit memory item;
		item.id = id;
		items[id] = item;
		require(_msgSender() == serviceLocator.getService(auditorFlowAddress), "Only Auditor flow is allowed to execute");
		uint oldAuditorId = item.auditorId;
		item.auditorId = auditorId;
		item.gitCommit = gitCommit;
		item.telegramId = telegramId;
		item.name = name;
		item.client = client;
		item.auditor = auditor;
		item.nda = nda;
		item.status = 0;
		items[id] = item;
		address newOwner = getItemOwner(item);
		_mint(newOwner, id);
		uint newAuditorId = item.auditorId;
		_setItemIdByAuditorId(oldAuditorId, newAuditorId, item.id);
		emit ItemUpdated(id, item.status);
		return id;
	}
/*
	### Transition: 'Give offer'
	This transition begins from `Requested` and leads to the state `Offered`.
	
	#### Transition Parameters
	For this transition, the following parameters are required: 
	
	* `Id` (Integer) - Audit identifier
	* `Price` (Money)
	
	#### Access Restrictions
	Access is specifically restricted to the user with the address from the `Auditor` property. If `Auditor` property is not yet set then the method caller becomes the objects `Auditor`.
	
	#### Checks and updates
	The following properties will be updated on blockchain:
	
	* `Price` (Money)
*/
	function giveOffer(uint256 id,uint price) external whenNotPaused nonReentrant returns (uint256) {
		Audit memory item = getItem(id);
		_assertOrAssignAuditor(item);
		_assertStatus(item, 0);
		address oldOwner = getItemOwner(item);
		item.price = price;
		item.status = 1;
		items[id] = item;
		address newOwner = getItemOwner(item);
		if (newOwner != oldOwner) {
			_transfer(oldOwner, newOwner, id);
		}
		emit ItemUpdated(id, item.status);
		return id;
	}
/*
	### Transition: 'Accept offer'
	This transition begins from `Offered` and leads to the state `In progress`.
	
	#### Access Restrictions
	Access is specifically restricted to the user with the address from the `Client` property. If `Client` property is not yet set then the method caller becomes the objects `Client`.
	
	#### Payment Process
	In the end a payment is made.
	A payment in the amount of `Price` is made from caller to the address specified in the `Auditor` property.
*/
	function acceptOffer(uint256 id) external whenNotPaused nonReentrant returns (uint256) {
		Audit memory item = getItem(id);
		_assertOrAssignClient(item);
		_assertStatus(item, 1);
		address oldOwner = getItemOwner(item);

		item.status = 2;
		items[id] = item;
		address newOwner = getItemOwner(item);
		if (newOwner != oldOwner) {
			_transfer(oldOwner, newOwner, id);
		}
		emit ItemUpdated(id, item.status);
		if (item.auditor != address(0) && item.price > 0){
			safeTransferFromExternal(token, _msgSender(), item.auditor, item.price);
		}
		return id;
	}
/*
	### Transition: 'Reject offer'
	This transition begins from `Offered` and leads to the state `Requested`.
	
	#### Access Restrictions
	Access is specifically restricted to the user with the address from the `Client` property. If `Client` property is not yet set then the method caller becomes the objects `Client`.
	
	#### Checks and updates
	The following calculations will be done and updated:
	
	* `Price` = `0`
*/
	function rejectOffer(uint256 id) external whenNotPaused nonReentrant returns (uint256) {
		Audit memory item = getItem(id);
		_assertOrAssignClient(item);
		_assertStatus(item, 1);
		address oldOwner = getItemOwner(item);
		item.price = 0;
		item.status = 0;
		items[id] = item;
		address newOwner = getItemOwner(item);
		if (newOwner != oldOwner) {
			_transfer(oldOwner, newOwner, id);
		}
		emit ItemUpdated(id, item.status);
		return id;
	}
/*
	### Transition: 'Complete audit'
	This transition begins from `In progress` and leads to the state `Completed`.
	
	#### Transition Parameters
	For this transition, the following parameters are required: 
	
	* `Id` (Integer) - Audit identifier
	* `Image` (Image)
	* `Description` (Text)
	
	#### Access Restrictions
	Access is specifically restricted to the user with the address from the `Auditor` property. If `Auditor` property is not yet set then the method caller becomes the objects `Auditor`.
	
	#### Checks and updates
	The following properties will be updated on blockchain:
	
	* `Image` (Image)
	* `Description` (String)
*/
	function completeAudit(uint256 id,string calldata image,string calldata description) external whenNotPaused nonReentrant returns (uint256) {
		Audit memory item = getItem(id);
		_assertOrAssignAuditor(item);
		_assertStatus(item, 2);
		address oldOwner = getItemOwner(item);
		item.image = image;
		item.description = description;
		item.status = 3;
		items[id] = item;
		address newOwner = getItemOwner(item);
		if (newOwner != oldOwner) {
			_transfer(oldOwner, newOwner, id);
		}
		emit ItemUpdated(id, item.status);
		return id;
	}
/*
	### Transition: 'Review'
	This transition begins from `Completed` and leads to the state `Reviewed`.
	
	#### Transition Parameters
	For this transition, the following parameters are required: 
	
	* `Id` (Integer) - Audit identifier
	* `Score` (Float)
	
	#### Access Restrictions
	Access is specifically restricted to the user with the address from the `Client` property. If `Client` property is not yet set then the method caller becomes the objects `Client`.
	
	#### External Method Calls
	This transition involves a call to an external method in the `0xLeague Auditor Profile` workflow through the `Add score` transition on the `Testnet` blockchain, using the address ``.
*/
	function review(uint256 id,uint score) external whenNotPaused nonReentrant returns (uint256) {
		Audit memory item = getItem(id);
		_assertOrAssignClient(item);
		_assertStatus(item, 3);
		address oldOwner = getItemOwner(item);
		IExternal0xleague_auditor_profile auditorFlow = IExternal0xleague_auditor_profile(serviceLocator.getService(auditorFlowAddress));
		item.status = 4;
		items[id] = item;
		address newOwner = getItemOwner(item);
		if (newOwner != oldOwner) {
			_transfer(oldOwner, newOwner, id);
		}
		emit ItemUpdated(id, item.status);
	auditorFlow.addScore(item.auditorId, score);
		return id;
	}
}