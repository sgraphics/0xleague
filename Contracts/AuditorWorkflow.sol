// SPDX-License-Identifier: UNLICENSED
// This smart contract code is proprietary.
// Unauthorized copying, modification, or distribution is strictly prohibited.
// For licensing inquiries or permissions, contact info@toolblox.net.
pragma solidity ^0.8.19;
interface IExternal0xleague_audit_management {
	function requestAudit(uint auditorId, string calldata gitCommit, string calldata telegramId, string calldata name, address client, address auditor, string calldata nda) external returns (uint);
}
import "https://raw.githubusercontent.com/Ideevoog/Toolblox.Token/main/Contracts/WorkflowBase.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.3/contracts/access/Ownable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.3/contracts/security/ReentrancyGuard.sol";
import "https://raw.githubusercontent.com/Ideevoog/Toolblox.Token/main/Contracts/OwnerPausable.sol";
/*
	Toolblox smart-contract workflow: https://app.toolblox.net/summary/0xleague_auditor_profile
*/
contract AuditorWorkflow  is WorkflowBase, Ownable, ReentrancyGuard, OwnerPausable{
	struct Auditor {
		uint id;
		uint64 status;
		string name;
		address auditor;
		string telegram;
		uint score;
		uint64 scoreCount;
		string image;
		string description;
		string twitter;
		string signedNda;
	}
	bytes32 auditFlowAddress = keccak256("0xleague_audit_management");
	mapping(uint => Auditor) public items;
	function _assertOrAssignAuditor(Auditor memory item) private view {
		address auditor = item.auditor;
		if (auditor != address(0))
		{
			require(_msgSender() == auditor, "Invalid Auditor");
			return;
		}
		item.auditor = _msgSender();
	}
	string _nda;
	function getNda() public view returns (string memory) {
		return _nda;
	}
	function setNda(string memory nda) public onlyOwner {
		_nda = nda;
	}
	constructor()  {
		_transferOwnership(_msgSender());
		serviceLocator = IExternalServiceLocator(0xABD5F9cFB2C796Bbd1647023ee2BEA74B23bf672);
	}
	function setOwner(address _newOwner) public {
		transferOwnership(_newOwner);
	}
/*
	Available statuses:
	0 Registered (owner Auditor)
	1 Disabled (owner Auditor)
*/
	function _assertStatus(Auditor memory item, uint64 status) private pure {
		require(item.status == status, "Cannot run Workflow action; unexpected status");
	}
	function getItem(uint256 id) public view returns (Auditor memory) {
		Auditor memory item = items[id];
		require(item.id == id, "Cannot find item with given id");
		return item;
	}
	function getLatest(uint256 cnt) public view returns(Auditor[] memory) {
		uint256[] memory latestIds = getLatestIds(cnt);
		Auditor[] memory latestItems = new Auditor[](latestIds.length);
		for (uint256 i = 0; i < latestIds.length; i++) latestItems[i] = items[latestIds[i]];
		return latestItems;
	}
	function getPage(uint256 cursor, uint256 howMany) public view returns(Auditor[] memory) {
		uint256[] memory ids = getPageIds(cursor, howMany);
		Auditor[] memory result = new Auditor[](ids.length);
		for (uint256 i = 0; i < ids.length; i++) result[i] = items[ids[i]];
		return result;
	}
	
	mapping(address => uint) public itemsByAuditor;
	function getItemIdByAuditor(address auditor) public view returns (uint) {
		return itemsByAuditor[auditor];
	}
	function getItemByAuditor(address auditor) public view returns (Auditor memory) {
		return getItem(getItemIdByAuditor(auditor));
	}
	function _setItemIdByAuditor(Auditor memory item, uint id) private {
		if (item.auditor == address(0))
		{
			return;
		}
		uint existingItemByAuditor = itemsByAuditor[item.auditor];
		require(
			existingItemByAuditor == 0 || existingItemByAuditor == item.id,
			"Cannot set Auditor. Another item already exist with same value."
		);
		itemsByAuditor[item.auditor] = id;
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
	function getAuditor(uint id) public view returns (address){
		return getItem(id).auditor;
	}
	function getTelegram(uint id) public view returns (string memory){
		return getItem(id).telegram;
	}
	function getScore(uint id) public view returns (uint){
		return getItem(id).score;
	}
	function getScoreCount(uint id) public view returns (uint64){
		return getItem(id).scoreCount;
	}
	function getImage(uint id) public view returns (string memory){
		return getItem(id).image;
	}
	function getDescription(uint id) public view returns (string memory){
		return getItem(id).description;
	}
	function getTwitter(uint id) public view returns (string memory){
		return getItem(id).twitter;
	}
	function getSignedNda(uint id) public view returns (string memory){
		return getItem(id).signedNda;
	}
/*
	### Transition: 'Create profile'
	#### Notes
	
	Agree with NDA and create profile
	This transition creates a new object and puts it into `Registered` state.
	
	#### Transition Parameters
	For this transition, the following parameters are required: 
	
	* `Name` (Text)
	* `Image` (Image)
	* `Twitter` (Text)
	* `Telegram` (Text)
	* `Description` (Text)
	
	#### Access Restrictions
	Access is specifically restricted to the user with the address from the `Auditor` property. If `Auditor` property is not yet set then the method caller becomes the objects `Auditor`.
	
	#### Checks and updates
	The following properties will be updated on blockchain:
	
	* `Name` (String)
	* `Image` (Image)
	* `Twitter` (String)
	* `Telegram` (String)
	* `Description` (String)
	
	The following calculations will be done and updated:
	
	* `Signed NDA` = `NDA`
*/
	function createProfile(string calldata name,string calldata image,string calldata twitter,string calldata telegram,string calldata description) external whenNotPaused nonReentrant returns (uint256) {
		uint256 id = _getNextId();
		Auditor memory item;
		item.id = id;
		items[id] = item;
		_assertOrAssignAuditor(item);
		_setItemIdByAuditor(item, 0);
		item.name = name;
		item.image = image;
		item.twitter = twitter;
		item.telegram = telegram;
		item.description = description;
		item.signedNda = getNda();
		item.status = 0;
		items[id] = item;
		_setItemIdByAuditor(item, id);
		emit ItemUpdated(id, item.status);
		return id;
	}
/*
	### Transition: 'Add score'
	This transition begins from `Registered` and leads to the state `Registered`.
	
	#### Transition Parameters
	For this transition, the following parameters are required: 
	
	* `Id` (Integer) - Auditor identifier
	* `New Score` (Float)
	
	#### Access Restrictions
	Access is exclusively provided to the workflow at URL: `0xleague_audit_management`.
	
	#### Checks and updates
	The following calculations will be done and updated:
	
	* `Score` = `( ( Score * Score Count ) + New Score ) / ( Score Count + 1 )`
	* `Score Count` = `Score Count + 1`
*/
	function addScore(uint256 id,uint newScore) external whenNotPaused nonReentrant returns (uint256) {
		Auditor memory item = getItem(id);
		require(_msgSender() == serviceLocator.getService(auditFlowAddress), "Only Audit flow is allowed to execute");
		_assertStatus(item, 0);
		item.score = ( ( item.score * item.scoreCount ) + newScore ) / ( item.scoreCount + 1 );
		item.scoreCount = item.scoreCount + 1;
		item.status = 0;
		items[id] = item;
		emit ItemUpdated(id, item.status);
		return id;
	}
/*
	### Transition: 'Update'
	This transition begins from `Registered` and leads to the state `Registered`.
	
	#### Transition Parameters
	For this transition, the following parameters are required: 
	
	* `Id` (Integer) - Auditor identifier
	* `Name` (Text)
	* `Image` (Image)
	* `Twitter` (Text)
	* `Telegram` (Text)
	* `Description` (Text)
	
	#### Access Restrictions
	Access is specifically restricted to the user with the address from the `Auditor` property. If `Auditor` property is not yet set then the method caller becomes the objects `Auditor`.
	
	#### Checks and updates
	The following properties will be updated on blockchain:
	
	* `Name` (String)
	* `Image` (Image)
	* `Twitter` (String)
	* `Telegram` (String)
	* `Description` (String)
*/
	function update(uint256 id,string calldata name,string calldata image,string calldata twitter,string calldata telegram,string calldata description) external whenNotPaused nonReentrant returns (uint256) {
		Auditor memory item = getItem(id);
		_assertOrAssignAuditor(item);
		_assertStatus(item, 0);
		_setItemIdByAuditor(item, 0);
		item.name = name;
		item.image = image;
		item.twitter = twitter;
		item.telegram = telegram;
		item.description = description;
		item.status = 0;
		items[id] = item;
		_setItemIdByAuditor(item, id);
		emit ItemUpdated(id, item.status);
		return id;
	}
/*
	### Transition: 'Disable profile'
	#### Notes
	
	Disabling account in line with NDA terms
	This transition begins from `Registered` and leads to the state `Disabled`.
	
	#### Access Restrictions
	Access is specifically restricted to the user with the address from the `Auditor` property. If `Auditor` property is not yet set then the method caller becomes the objects `Auditor`.
*/
	function disableProfile(uint256 id) external whenNotPaused nonReentrant returns (uint256) {
		Auditor memory item = getItem(id);
		_assertOrAssignAuditor(item);
		_assertStatus(item, 0);
		_setItemIdByAuditor(item, 0);
		item.status = 1;
		items[id] = item;
		_setItemIdByAuditor(item, id);
		emit ItemUpdated(id, item.status);
		return id;
	}
/*
	### Transition: 'Rejoin'
	#### Notes
	
	Activates account profile in line with the active NDA signs the NDA
	This transition begins from `Disabled` and leads to the state `Registered`.
	
	#### Access Restrictions
	Access is specifically restricted to the user with the address from the `Auditor` property. If `Auditor` property is not yet set then the method caller becomes the objects `Auditor`.
	
	#### Checks and updates
	The following calculations will be done and updated:
	
	* `Signed NDA` = `NDA`
*/
	function rejoin(uint256 id) external whenNotPaused nonReentrant returns (uint256) {
		Auditor memory item = getItem(id);
		_assertOrAssignAuditor(item);
		_assertStatus(item, 1);
		_setItemIdByAuditor(item, 0);
		item.signedNda = getNda();
		item.status = 0;
		items[id] = item;
		_setItemIdByAuditor(item, id);
		emit ItemUpdated(id, item.status);
		return id;
	}
/*
	### Transition: 'Request audit'
	This transition begins from `Registered` and leads to the state `Registered`.
	
	#### Transition Parameters
	For this transition, the following parameters are required: 
	
	* `Id` (Integer) - Auditor identifier
	* `Audit name` (Text)
	* `Git commit` (Text)
	* `Client telegram` (Text)
	
	#### Checks and updates
	The following calculations will be done and updated:
	
	*  `Audit requester` = `caller`
	
	#### External Method Calls
	This transition involves a call to an external method in the `0xLeague Audit Management` workflow through the `Request audit` transition on the `Testnet` blockchain, using the address ``.
*/
	function requestAudit(uint256 id,string calldata auditName,string calldata gitCommit,string calldata clientTelegram) external whenNotPaused nonReentrant returns (uint256) {
		Auditor memory item = getItem(id);
		_assertStatus(item, 0);
		address auditRequester = _msgSender();
		IExternal0xleague_audit_management auditFlow = IExternal0xleague_audit_management(serviceLocator.getService(auditFlowAddress));
		item.status = 0;
		items[id] = item;
		emit ItemUpdated(id, item.status);
	auditFlow.requestAudit(item.id, gitCommit, clientTelegram, auditName, auditRequester, item.auditor, item.signedNda);
		return id;
	}
}