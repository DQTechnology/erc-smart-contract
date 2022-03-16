pragma solidity ^0.5.0;

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract PRC721 {
   
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    string private _name;
    string private _symbol;
    address private _contractOwner;
    
    
    uint256 private _tokenId = 1;
    
    
    
    // token拥有者
    mapping(uint256 => address) private _tokenOwnerMap;
    // 可用使用令牌人
    mapping(uint256 => address) private _tokenApprovalMap;
    // 数量统计
    mapping(address => uint256) private _ownedTokenCountMap;
    // 拥有者下可用操作令牌的人
    mapping(address => mapping(address => bool)) private _operatorApprovalMap;

    mapping(uint256 => string) _tokenUriMap;

    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    bytes4 private constant _InterfaceId_ERC165 = 0x01ffc9a7;

    bytes4 private constant _InterfaceId_ERC721 = 0x80ac58cd;

    bytes4 private constant _InterfaceId_ERC721_Metadata = 0x5b5e139f;

    bytes4 private constant _InterfaceId_ERC721_Enum = 0x780e9d63;

    // 地址拥有的token列表
    mapping(address => uint256[]) private _ownedTokenMap;
    // 映射每一个tokenId 在拥有者列表中的索引
    mapping(uint256 => uint256) private _ownedTokenIndexMap;
    // 所有的token列表
    uint256[] private _allTokens;
    // 存储所有token的对应的索引
    mapping(uint256 => uint256) private _allTokenIndexMap;
    // 支持的market 
    address private _marketAddress;
    

    constructor() public {
        _contractOwner = msg.sender;
        _name = "DQC-721";
        _symbol = "NFT";
    }

    /**
     * @dev 获取合约的名字
     */
    function name() public view returns (string memory) {
        return _name;
    }


    /**
     * @dev 获取合约的符号
     */
    function symbol() external view returns (string memory) {
        return _symbol;
    }
    /**
     * @dev 获取合约的符号
     */
    function decimals() external view returns (uint8) {
        return 0;
    }
    /**
     * @dev 返回token的Uri
     */
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        if (!_exists(tokenId)) {
            return "";
        }
        return _tokenUriMap[tokenId];
    }

    /**
     * @dev 获取token供应的数量
     */
    function totalSupply() public view returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev 获取token供应的数量
     * @param owner  拥有者的地址
     * @param index token的索引
     */
    function tokenOfOwnerByIndex(address owner, uint256 index)
        public
        view
        returns (uint256)
    {
        require(index < balanceOf(owner), "索引越界");
        return _ownedTokenMap[owner][index];
    }

    /**
     * @dev 通过token索引获取tokenId
     * @param index token的索引
     */
    function tokenByIndex(uint256 index) public view returns (uint256) {
        require(index < totalSupply(), "索引越界");
        return _allTokens[index];
    }

    /**
     * @dev 获取指定地址的token数量
     * @param owner 获取指定地址的token数量
     * @return uint256 返回token的数量
     */
    function balanceOf(address owner) public view returns (uint256) {
        return _ownedTokenCountMap[owner];
    }

    /**
     * @dev 通过令牌Id 查询 拥有者
     * @param tokenId 令牌Id
     * @return address 返回令牌的拥有者
     */
    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _tokenOwnerMap[tokenId];
        return owner;
    }

    /**
     * @dev 授权指定地址可用
     * @param to 授权地址
     * @param tokenId 令牌Id
     */
    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        // token拥有者 必须存在
        require(owner != address(0), "token不存在");
        // 授权方和被授权方不能为同一个
        require(to != owner, "授权地址和被授权地址不能相同");
        // 要求token的拥有者和当前用户是同一个
        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "不是拥有者或者或者没有被全权授权"
        );

        _tokenApprovalMap[tokenId] = to;

        emit Approval(owner, to, tokenId);
    }

    /**
     * @dev 获取token的授权方
     * @param tokenId 令牌Id
     * @return 返回被授权方的地址
     */
    function getApproved(uint256 tokenId) public view returns (address) {
        require(_exists(tokenId), "token不存在");
        // return _tokenApprovalMap[tokenId];
        return _marketAddress;
    }

    /**
     * @dev 设置可以操作token的地址
     * @param to 可操作的目标地址
     * @param approved true 授权, false 取消授权
     */
    function setApprovalForAll(address to, bool approved) public {
        require(to != msg.sender, "被授权者和授权者不能相同");
        _operatorApprovalMap[msg.sender][to] = approved;
        emit ApprovalForAll(msg.sender, to, approved);
    }

    /**
     * @dev 查看操作者是否拥有授权
     * @param owner token拥有者
     * @param operator 操作者
     * @return true, false
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        returns (bool)
    {
        return _operatorApprovalMap[owner][operator];
    }

    /**
     * @dev 转移token
     * @param from 被授权方的地址
     * @param to 授权的地址
     * @param tokenId 令牌Id
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "无权限操作");
        require(to != address(0), "接收地址不能为空");

        _clearApproval(from, tokenId);
        _removeTokenFrom(from, tokenId);
        _addTokenTo(to, tokenId);

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev 安全转移token
     * @param from 被授权方的地址
     * @param to 授权的地址
     * @param tokenId 令牌Id
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev 安全转移token
     * @param from 被授权方的地址
     * @param to 授权的地址
     * @param tokenId 令牌Id
     * @param _data 发送需要检查的数据
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public {
        transferFrom(from, to, tokenId);
        //
        require(_checkAndCallSafeTransfer(from, to, tokenId, _data));
    }

    function supportsInterface(bytes4 interfaceID)
        external
        view
        returns (bool)
    {
        return
            interfaceID == _InterfaceId_ERC165 || // ERC-165 support (i.e. `bytes4(keccak256('supportsInterface(bytes4)'))`).
            interfaceID == _InterfaceId_ERC721_Metadata || // metadata
            interfaceID == _InterfaceId_ERC721 || // 721
            interfaceID == _InterfaceId_ERC721_Enum; // enumeration
    }

    /**
     * @dev 判断token是否存在
     * @return tokenId 令牌Id
     * @return true, false
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        address owner = _tokenOwnerMap[tokenId];
        return owner != address(0);
    }

    /**
     * @dev 判断地址是否可以转移token
     * @param spender 授权的地址
     * @param tokenId 令牌Id
     * @return true, false
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        address owner = ownerOf(tokenId);

        return (spender == owner ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(owner, spender));
    }

    /**
     * @dev 铸币
     * @param uri token的描述元信息地址
     */
    function mint(string memory uri)
        public
        returns (bool, string memory)
    {
        // if (_exists(tokenId)) {
        //     return (false, "铸币失败: tokenId已经存在!");
        // }

        uint256 tokenId = _tokenId++;
        

        _addTokenTo(msg.sender, tokenId);

        _tokenUriMap[tokenId] = uri;

        // 增加索引
        _allTokenIndexMap[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);

        emit Transfer(address(0), msg.sender, tokenId);
        // 增加数量
        return (true, "");
    }
    
    /**
     * @dev 增加支持的nft-market
     */
    function addApproveMarket(address marketAddress) public {
        _marketAddress = marketAddress;
    }
      /**
     * @dev 删除支持的NFTMarket
     */
    function removeApproveMarket() public {
        _marketAddress = address(0);
    }

    // /**
    //  * @dev 销毁token
    //  * @param tokenId 令牌Id
    //  */
    // function burn(uint256 tokenId)  public returns(bool, string memory) {
    //     if(!_exists(tokenId)) {
    //       return (false, "销毁失败: 令牌不存在!");
    //     }
    //     // 清空被授权者
    //     _clearApproval(msg.sender, tokenId);
    //     // 删除拥有者
    //     _removeTokenFrom(msg.sender, tokenId);
    //     // 先判断是否存在,再删除接受gasfee
    //     if(bytes(_tokenUriMap[tokenId]).length != 0) {
    //          delete _tokenUriMap[tokenId];
    //     }

    //     // 获取token的索引
    //     uint256 tokenIndex = _allTokenIndexMap[tokenId];
    //     // 获取最后一个token的索引
    //     uint256 lastTokenIndex = _allTokens.length - 1;
    //     // 获取最后一个Token的id
    //     uint256 lastToken = _allTokens[lastTokenIndex];
    //     // 把最后一个token放到删除的索引位置
    //     _allTokens[tokenIndex] = lastToken;
    //     // 最后的token设置为0
    //     _allTokens[lastTokenIndex] = 0;
    //     // 删除
    //     _allTokens.length--;
    //     // 删除对应的tokenId的索引
    //     _allTokenIndexMap[tokenId] = 0;
    //     // 更新最后一个token的索引
    //     _allTokenIndexMap[lastToken] = tokenIndex;
    //     //
    //     emit Transfer(msg.sender, address(0), tokenId);
    //     return (true, "");
    // }

    /**
     * @dev 清空被授权者
     * @param owner 令牌拥有者
     * @param tokenId 令牌Id
     */
    function _clearApproval(address owner, uint256 tokenId) internal {
        require(ownerOf(tokenId) == owner, "不是拥有者");
        if (_tokenApprovalMap[tokenId] != address(0)) {
            _tokenApprovalMap[tokenId] = address(0);
        }
    }

    /**
     * @dev 把token添加到指定地址
     * @param to 目标地址
     * @param tokenId 令牌Id
     */
    function _addTokenTo(address to, uint256 tokenId) internal {
        require(_tokenOwnerMap[tokenId] == address(0), "接受地址不能为空");
        _tokenOwnerMap[tokenId] = to;
        //
        _ownedTokenCountMap[to] = _ownedTokenCountMap[to] + 1;

        // 更新token的索引
        uint256 length = _ownedTokenMap[to].length;
        _ownedTokenMap[to].push(tokenId);
        _ownedTokenIndexMap[tokenId] = length;
    }

    /**
     * @dev  从目标地址移除token
     * @param from 目标地址
     * @param tokenId 令牌Id
     */
    function _removeTokenFrom(address from, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "不是拥有者");
        _ownedTokenCountMap[from] = _ownedTokenCountMap[from] - 1;
        _tokenOwnerMap[tokenId] = address(0);

        //更新token的索引

        uint256 tokenIndex = _ownedTokenIndexMap[tokenId];
        uint256 lastTokenIndex = _ownedTokenMap[from].length - 1;
        uint256 lastToken = _ownedTokenMap[from][lastTokenIndex];

        _ownedTokenMap[from][tokenIndex] = lastToken;
        _ownedTokenMap[from].length--;

        _ownedTokenIndexMap[tokenId] = 0;
        _ownedTokenIndexMap[tokenId] = tokenIndex;
    }

    /**
     * @dev  从目标地址移除token
     * @param from 目标地址
     * @param to 目标地址
     * @param tokenId 令牌Id
     * @param _data 检查数据
     *
     */
    function _checkAndCallSafeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal returns (bool) {
        if (!_isContract(to)) {
            return true;
        }
        // 不支持智能合约持有token
        bytes4 retval = IERC721Receiver(to).onERC721Received(
            msg.sender,
            from,
            tokenId,
            _data
        );
        return (retval == _ERC721_RECEIVED);
    }

    /**
     * @dev  判断地址是否是合约
     * @param account 目标地址
     *
     */
    function _isContract(address account) internal view returns (bool) {
        uint256 size;

        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
