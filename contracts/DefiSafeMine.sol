pragma solidity 0.6.0;
import "./ERC20Interface.sol";
import "./SafeMath.sol";

contract DefiSafeMine {

    using SafeMath for uint256;

    address payable owner;
    struct User {
        address name;
        uint256 tokenID;
        //lp
        uint256 userTokenAmount;
    }

    struct TokenPool {
        uint256 tokenID;
        uint256 poolTokenAmount;
        uint256 userAmount;
        mapping(address => User) users;
    }

    struct PlatformData {
        uint256 mortgageTokenTotal;// Token total
    }
    //Environmental statistics
    PlatformData public platformDataManager;

     //TokenID protocol
    mapping(uint256 => address) public tokenIDProtocol;
    //Token Pool management
    mapping(uint256 => TokenPool) private tokenPools;

    struct LockedAccountsStruct {
        uint256 totalAmount;
        mapping(uint256 => address) lockAccounts;
    }

    //Control difficulty account management
    LockedAccountsStruct private lockAccountsManager;

    address public defiSafeTokenAddress;
    uint256 constant private C1 = 4;
    uint256 constant private C2 =21;
    uint256 constant private DSE_TOKEN_INIT_TOTAL = 1000000000 * 1e18;

    struct CommunityUser {
        address name;
        //0:No,10:Yes
        uint256 authorization;
    }
    struct CommunityManager{
        uint256 totalUsers;
        //Zero starts stacking
        mapping(uint256 => CommunityUser)users;
    }
    CommunityManager private communityManager;

  
    address private communityAccount;
    uint256 public communityRatio;

    struct MineManagerStruct {
        uint256 totalMinersCount;
        uint256 mineTotalTokens;
        //10:Have authority to mine
        mapping(address => uint256) minersPermissions;
    }
    MineManagerStruct private mineManager;

    event MineTokensEvent(address miner,address user,uint256 mineTokens);
    event Deposit(uint256 tokenID,uint256 tokenAmount);
    event UnlockAssets(uint256 tokenID,uint256 tokenAmount);

    constructor() public {
        owner = msg.sender;
        mineManager = MineManagerStruct({totalMinersCount: 0,mineTotalTokens:0});
        lockAccountsManager = LockedAccountsStruct({totalAmount : 1});
        platformDataManager = PlatformData({mortgageTokenTotal: 0});
        lockAccountsManager.lockAccounts[0] = address(this);
        communityManager = CommunityManager({totalUsers:1});
        communityManager.users[0] = CommunityUser({name: owner,authorization: 0});
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier communityAuthorization() {
        for (uint256 userID = 0;userID < communityManager.totalUsers;userID++){
            CommunityUser storage user = communityManager.users[userID];
            require(user.authorization == 10,"Authorization not passed .");
        }
        (uint256 isExist,) = isCommunityUser();
        require(isExist == 10,"No CommunityUser .");
        _;
    }

    //isExist:10-yes
    function isCommunityUser()public view returns(uint256 _isExist,uint256 _userID){
        for (uint256 userID = 0;userID < communityManager.totalUsers;userID++){
            CommunityUser storage user = communityManager.users[userID];
            if(user.name == msg.sender){
                return (10,userID);
            }
        }
        return (0,0);
    }


    function communityUserAuthorizationState(uint256 userID)public view returns(uint256){
        require(userID < communityManager.totalUsers,"No User");
        CommunityUser storage user = communityManager.users[userID];
        return user.authorization;
    }

    function communityUserAuthorizationPerform()public returns(uint256) {
        (uint256 isExist,uint256 userID) = isCommunityUser();
        require(isExist == 10,"No Exist .");
        CommunityUser storage user = communityManager.users[userID];
        user.authorization = 10;
        return 1;
    }


    function communityAuthorizationClear()private returns(uint256){
        for (uint256 userID = 0;userID < communityManager.totalUsers;userID++){
            CommunityUser storage user = communityManager.users[userID];
            user.authorization = 0;
        }
        return 1;
    }


    function communityAddUser(address userAddress)public communityAuthorization returns(uint256){
        require(communityManager.totalUsers < 100,"Members too much .");
        require(userAddress != address(0),"userAddress error .");
        communityManager.users[communityManager.totalUsers] = CommunityUser({name: userAddress,authorization: 0});
        communityManager.totalUsers = communityManager.totalUsers.add(1);
        communityAuthorizationClear();
        return 1;
    }

    function communityRemoveUser(address userAddress)public returns(uint256){
        (uint256 isExist,uint256 userID) = isCommunityUser();
        require(isExist == 10,"No Exist .");
        require(communityManager.totalUsers > 5,"Don't allow .");
        uint256 authorizationUsers = 0;
        uint256 removeUserID = 101;
        for (uint256 userID = 0;userID < communityManager.totalUsers;userID++){
            CommunityUser storage user = communityManager.users[userID];
            if(user.authorization == 10){
                authorizationUsers = authorizationUsers.add(1);
            }
            if(user.name == userAddress){
                removeUserID = userID;
            }
        }
        require(authorizationUsers > communityManager.totalUsers.sub(2),"Don't allow .");
        bool isRemove = false;       
        for (uint256 userID = 0;userID < communityManager.totalUsers;userID++){
            if(userID == removeUserID){
                isRemove = true;
            }
            if(isRemove){
                communityManager.users[userID] = communityManager.users[userID+1];
            }
        }
        require(isRemove,"CommunityRemoveUser error .");
        communityManager.totalUsers = communityManager.totalUsers.sub(1);
    }

    function communityUsersGet()public view returns(uint256){
        return communityManager.totalUsers;
    }

    function setCommunityRatio(uint256 _ratio)public communityAuthorization{
        communityRatio = _ratio;
        communityAuthorizationClear();
    }

    //
    function dseTokenMigration(uint256 _tokenAmount,address _receive)public communityAuthorization{
        require(_tokenAmount > 0,"value error .");
        require(_receive != address(0),"Receive address error .");
        ERC20 defiSafeToken = ERC20(defiSafeTokenAddress);
        require(_tokenAmount <= defiSafeToken.balanceOf(address(this)),"Lack of balance .");
        require(defiSafeToken.transfer(_receive,_tokenAmount),"DseTokenMigration error .");
    }

    //Set MortgageToken token
    function addMortgageToken(uint256 _tokenID,address _mortgageToken) public communityAuthorization{
        require(tokenIDProtocol[_tokenID] == address(0),"Token is already supported.");
        require(_mortgageToken != address(0),"Invalid token address .");
        require(_tokenID == platformDataManager.mortgageTokenTotal,"TokenID error .");
        tokenIDProtocol[_tokenID] = _mortgageToken;
        platformDataManager.mortgageTokenTotal = platformDataManager.mortgageTokenTotal.add(1);
        distributionTokenPool(_tokenID);
        communityAuthorizationClear();
    }

        //Distribute token pool
    function distributionTokenPool(uint256 _tokenID) private{
        tokenPools[_tokenID] = TokenPool({
            tokenID: _tokenID,
            poolTokenAmount: 0,
            userAmount: 0
        });
    }

    function deposit(uint256 _tokenType,uint256 _tokenAmount)external payable{
        require(_tokenType < platformDataManager.mortgageTokenTotal,"Deposit TokenType error .");
        require(_tokenAmount > 0,"Deposit TokenAmount error .");
        address tokenAddress = tokenIDProtocol[_tokenType];
        require(tokenAddress != address(0),"Deposit tokenAddress error .");
        ERC20 tokenManager = ERC20(tokenAddress);
        require(_tokenAmount <= tokenManager.balanceOf(msg.sender),"Lack of balance .");
        require(tokenManager.allowance(msg.sender,address(this)) >= _tokenAmount,"Approve Error .");
        require(tokenManager.transferFrom(msg.sender,address(this),_tokenAmount),"TransferFrom error .");

        TokenPool storage pool = tokenPools[_tokenType];
        User storage user = pool.users[msg.sender];
        pool.userAmount = pool.userAmount + 1;
        pool.poolTokenAmount = pool.poolTokenAmount + _tokenAmount;
        
        user.name = msg.sender;
        user.tokenID = _tokenType;
        user.userTokenAmount = _tokenAmount;

        emit Deposit(_tokenType,_tokenAmount);
    }


    function unlockAssets()external {
        (uint256 isDesposit,uint256 tokenType) = getUserDepositTokenType(msg.sender);
        require(isDesposit == 1,"No Desposit .");
        address tokenAddress = tokenIDProtocol[tokenType];
        require(tokenAddress != address(0),"TokenAddress error .");
        ERC20 tokenManager = ERC20(tokenAddress);
        
        TokenPool storage pool = tokenPools[tokenType];
        User storage user = pool.users[msg.sender];
        require(user.userTokenAmount > 0,"No Deposit .");
        require(tokenManager.transfer(msg.sender,user.userTokenAmount),"UnlockAssets error .");

        uint256 unlock =  user.userTokenAmount;
        pool.userAmount = pool.userAmount - 1;
        pool.poolTokenAmount = pool.poolTokenAmount - user.userTokenAmount;
        user.userTokenAmount = 0;

        emit UnlockAssets(tokenType,unlock);
    }


    function setCommunityAccount(address _communityAddress)public communityAuthorization{
        require(_communityAddress != address(0),"communityAddress error !");
        communityAccount = _communityAddress;
        communityAuthorizationClear();
    }

    function setLockAccountsManager(uint256 accountID,address accountAddress)public communityAuthorization{
        require(accountAddress != address(0),"accountAddress error !");
        require(lockAccountsManager.lockAccounts[accountID] == address(0),"accountAddress is already supported.");
        require(lockAccountsManager.totalAmount == accountID,"accountID error.");

        lockAccountsManager.lockAccounts[accountID] = accountAddress;
        lockAccountsManager.totalAmount = lockAccountsManager.totalAmount+1;
        communityAuthorizationClear();
    }

    function setDefiSafeMineAddress(address _addr)public communityAuthorization {
        require(_addr != address(0),"DefiSafeMineAddress error .");
        uint256 authority = mineManager.minersPermissions[_addr];
        require(authority != 10,"Has authorized .");
        mineManager.minersPermissions[_addr] = 10;
        mineManager.totalMinersCount = mineManager.totalMinersCount.add(1);
        communityAuthorizationClear();
    }

    function removeDefiSafeMineAddress(address _addr)public communityAuthorization {
        require(_addr != address(0),"DefiSafeMineAddress error .");
        uint256 authority = mineManager.minersPermissions[_addr];
        require(authority == 10,"No Authority .");
        mineManager.minersPermissions[_addr] = 0;
        mineManager.totalMinersCount = mineManager.totalMinersCount.sub(1);
        communityAuthorizationClear();
    }

    function setDefiSafeTokenAddress(address _addr)public communityAuthorization {
        require(_addr != address(0),"DefiSafeTokenAddress error .");
        defiSafeTokenAddress = _addr;
        communityAuthorizationClear();
    }

    function getMinerPermission(address miner) private returns(bool){
        uint256 authority = mineManager.minersPermissions[miner];
        if(authority == 10){
            return true;
        }else{
            return false;
        }
    }

    function getUserDepositTokenType(address _user)public view returns(uint256 isDesposit,uint256 _tokenType){
        require(_user != address(0),"User address error .");
        for(uint tokenID = 0;tokenID<platformDataManager.mortgageTokenTotal;tokenID++){
            TokenPool storage pool = tokenPools[tokenID];
            User storage user = pool.users[_user];
            if(user.userTokenAmount > 0){
                return (1,tokenID);
            }
        }
        return (0,0);
    }

    function increaseOutput(uint256 _outDSE,address _user)public view returns(uint256){
        require(_outDSE > 0,"NO OUT");
        require(_user != address(0),"User address error .");
        (uint256 isDesposit,uint256 tokenType) = getUserDepositTokenType(_user);
        if(isDesposit == 1){
            TokenPool storage pool = tokenPools[tokenType];
            User storage user = pool.users[_user];
            uint256 addOutDSE = mulDiv(_outDSE,user.userTokenAmount,pool.poolTokenAmount);
            addOutDSE = addOutDSE.mul(3);
            return addOutDSE;
        }
        return _outDSE;
    }

    function startMine(uint256 userTotalAssets,uint256 loseAssets,address receiveAddress) public{
        require(getMinerPermission(msg.sender),"No permission .");
        require(receiveAddress != address(0),"rec address error .");
        require(defiSafeTokenAddress != address(0),"DefiSafeTokenAddress no init .");
        require(lockAccountsManager.totalAmount > 2,"lockAccountsManager no set .");
        require(communityAccount != address(0),"communityAccount error !");
        ERC20 defiSafeToken = ERC20(defiSafeTokenAddress);
        uint256 tokenMineBalance = defiSafeToken.balanceOf(address(this));
        require(tokenMineBalance > 0,"No DSE");
        require(userTotalAssets > 0,"No userTotalAssets");
        require(loseAssets > 0,"No loseAssets");

        (uint256 userTokens,uint256 communityTokens) = getUserClaimAmount(userTotalAssets,loseAssets,receiveAddress);
        require(defiSafeToken.transfer(receiveAddress,userTokens),"user receive tokens error !");
        require(defiSafeToken.transfer(communityAccount,communityTokens),"community receive tokens error !");
        mineManager.mineTotalTokens = mineManager.mineTotalTokens.add(userTokens);
        mineManager.mineTotalTokens = mineManager.mineTotalTokens.add(communityTokens);

        emit MineTokensEvent(msg.sender,receiveAddress,userTokens);
    }

    function getUserClaimAmount(uint256 userTotalAssets,uint256 loseAssets,address user) public view returns(uint256 userTokens,uint256 communityTokens){

        require(defiSafeTokenAddress != address(0),"DefiSafeTokenAddress no init .");
        require(lockAccountsManager.totalAmount > 2,"lockAccountsManager no set .");
        ERC20 defiSafeToken = ERC20(defiSafeTokenAddress);
        uint256 tokenMineBalance = defiSafeToken.balanceOf(address(this));
        require(tokenMineBalance > 0,"No DSE");
        require(userTotalAssets > 0,"No userTotalAssets");
        require(loseAssets > 0,"No loseAssets");

        uint256 baseOutDSE = releaseRulesDSE(userTotalAssets);
        uint256 loseOutDSE = releaseRulesDSE(loseAssets);
    
        uint256 outDSEStage = mineManager.mineTotalTokens.add(baseOutDSE);
        if(outDSEStage <= (10000000 * 1e18)){
            loseOutDSE = loseOutDSE.mul(20);
        }else if(outDSEStage <= (40000000 * 1e18)){
            loseOutDSE = loseOutDSE.mul(10);
        }else if(outDSEStage <= (100000000 * 1e18)){
            loseOutDSE = loseOutDSE.mul(6);
        }else{
            loseOutDSE = loseOutDSE.mul(4);
        }
        uint256 totalOutDSE = increaseOutput(baseOutDSE+loseOutDSE,user);
        require(totalOutDSE > 0,"TotalOutDSE error");
        uint256 realMineTokens = 0;
        if(tokenMineBalance > totalOutDSE){
            realMineTokens = totalOutDSE;
        }else{
            realMineTokens = tokenMineBalance;
        }
        communityTokens = mulDiv(realMineTokens,communityRatio,100);
        userTokens = realMineTokens.sub(communityTokens);
    }


    function releaseRulesDSE(uint256 assertsAmount)private view returns(uint256){

        ERC20 defiSafeToken = ERC20(defiSafeTokenAddress);
        uint256 tokenAssertRatio = mulDiv(assertsAmount,C1,C2);
        uint256 tokenSurplusBalance = 0;
        uint256 tokenMineBalance = defiSafeToken.balanceOf(address(this));
        for(uint i = 0;i<(lockAccountsManager.totalAmount);i++){
            address lockAccount = lockAccountsManager.lockAccounts[i];
            uint256 lockAccountTokenBalance = defiSafeToken.balanceOf(lockAccount);
            tokenSurplusBalance = tokenSurplusBalance.add(lockAccountTokenBalance);
        }
        uint256 tokenFree = DSE_TOKEN_INIT_TOTAL.sub(tokenSurplusBalance);
        uint256 tokenFreeRatio = tokenFree.div(1e18);
        uint256 tokenTotalRatio = DSE_TOKEN_INIT_TOTAL.div(1e18);
        uint256 tokenDifficulty = mulDiv(tokenAssertRatio,tokenFreeRatio,tokenTotalRatio);
        uint256 mineTokens = tokenAssertRatio.sub(tokenDifficulty);
        return mineTokens;
    }


    function getTotalTokensOfMine()public view returns(uint256){
        return mineManager.mineTotalTokens;
    }

    function getTotalTokensOfFree()public view returns(uint256){
        ERC20 defiSafeToken = ERC20(defiSafeTokenAddress);
        uint256 tokenSurplusBalance = 0;
        for(uint i = 0;i<(lockAccountsManager.totalAmount);i++){
            address lockAccount = lockAccountsManager.lockAccounts[i];
            uint256 lockAccountTokenBalance = defiSafeToken.balanceOf(lockAccount);
            tokenSurplusBalance = tokenSurplusBalance.add(lockAccountTokenBalance);
        }
        uint256 tokenFree = DSE_TOKEN_INIT_TOTAL.sub(tokenSurplusBalance);
        return tokenFree;
    }

    function getLockAccount(uint256 accountID)public view returns(address){
        require(accountID < lockAccountsManager.totalAmount,"accountID error .");
        return lockAccountsManager.lockAccounts[accountID];
    }

     function mulDiv (uint256 _x, uint256 _y, uint256 _z) public pure returns (uint256) {
        uint256 temp = _x.mul(_y);
        return temp.div(_z);
    }
}