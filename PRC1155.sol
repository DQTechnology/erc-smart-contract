pragma solidity ^0.5.0;
// https://dq-live-alpha.obs.cn-north-4.myhuaweicloud.com/public%2F213%2Fbcw%2F16470774010391647077401039-nft.json
interface ERC1155TokenReceiver {
    //
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    //
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}

contract PRC1155 {
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    event URI(string value, uint256 indexed id);

    bytes4 internal constant ERC1155_ACCEPTED = 0xf23a6e61;

    bytes4 internal constant ERC1155_BATCH_ACCEPTED = 0xbc197c81;

    bytes4 private constant _InterfaceId_ERC165 = 0x01ffc9a7;

    bytes4 private constant _InterfaceId_ERC1155 = 0xd9b67a26;

    bytes4 private constant _InterfaceId_ERC1155_Metadata = 0xd9b67a26;

    address private _contractOwner;

    // id => (owner => balance)
    mapping(uint256 => mapping(address => uint256)) private _balanceMap;

    // id => uint256 id的总value
    mapping(uint256 => uint256) private _idValueMap;

    // owner => (operator => approved)
    mapping(address => mapping(address => bool)) private _operatorApprovalMap;

    // id => uri
    mapping(uint256 => string) private _tokenUriMap;

    string private _name;

    uint256 private _tokenId = 1;
    
        // 支持的market 
    address private _marketAddress;
	
	
    string private _symbol;

    constructor() public {
        _contractOwner = msg.sender;
        _name = "DQ-1155-5";
        _symbol = "NFT1155";
    }

    /**
     * @dev 获取合约的名字
     */
    function name() external view returns (string memory) {
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
     * @dev 获取合约的符号
     */
    function uri(uint256 id) external view returns (string memory) {
        return _tokenUriMap[id];
    }

    /**
     * @dev 安全转移value
     * @param from 源地址
     * @param to 接收目标地址
     * @param id id
     * @param value 转移的值
     * @param data 转移的值
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external {
        require(to != address(0), "接收地址不能为空");

        // 判断地址的合法性
        require(
            from == msg.sender ||
                _operatorApprovalMap[from][msg.sender] == true,
            "无权限操作"
        );

        // 转移的值需要小于等于可以操作的值
        require(value <= _balanceMap[id][from], "余额不足");

        // 接收值
        _balanceMap[id][from] = _balanceMap[id][from] - value;

        uint256 tempBalance = _balanceMap[id][to] + value;

        require(tempBalance >= _balanceMap[id][to], "余额溢出!");

        _balanceMap[id][to] = tempBalance;

        emit TransferSingle(msg.sender, from, to, id, value);

        // 如果是合约的话需要调用
        if (_isContract(to)) {
            _doSafeTransferAcceptanceCheck(
                msg.sender,
                from,
                to,
                id,
                value,
                data
            );
        }
    }

    /**
     * @dev 批量转移安全转移value
     * @param from 源地址
     * @param to 接收目标地址
     * @param ids id
     * @param values 转移的值
     * @param data 转移的值
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external {
        require(to != address(0), "接收地址不能为空");

        require(ids.length == values.length, "ids和values的长度要相同");

        // 判断地址的合法性
        require(
            from == msg.sender ||
                _operatorApprovalMap[from][msg.sender] == true,
            "无操作权限"
        );

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];

            uint256 value = values[i];

            // 转移的值需要小于等于可以操作的值
            require(value <= _balanceMap[id][from], "余额不足");

            // 接收值
            _balanceMap[id][from] = _balanceMap[id][from] - value;
            //
            //

            // 检测两个值相加
            uint256 tempBalance = _balanceMap[id][to] + value;

            require(tempBalance >= _balanceMap[id][to], "余额溢出!");

            _balanceMap[id][to] = tempBalance;
        }

        emit TransferBatch(msg.sender, from, to, ids, values);

        if (_isContract(to)) {
            _doSafeBatchTransferAcceptanceCheck(
                msg.sender,
                from,
                to,
                ids,
                values,
                data
            );
        }
    }

    /**
     * @dev 获取拥有者的id数量
     * @param owner 拥有者地址
     * @param id id
     */
    function balanceOf(address owner, uint256 id)
        external
        view
        returns (uint256)
    {
        return _balanceMap[id][owner];
    }

    /**
     * @dev 批量获取拥有者的id数量
     * @param owners 拥有者地址
     * @param ids ids
     */
    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory)
    {
        require(owners.length == ids.length);

        uint256[] memory balances = new uint256[](owners.length);

        for (uint256 i = 0; i < owners.length; ++i) {
            balances[i] = _balanceMap[ids[i]][owners[i]];
        }

        return balances;
    }

    /**
     * @dev 增加操作者
     * @param operator 操作者的地址
     * @param approved 是否许可
     */
    function setApprovalForAll(address operator, bool approved) external {
        require(operator != address(0), "被授权地址不能为空");

        _operatorApprovalMap[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev 判断操作者是否被许可
     * @param owner 操作者的地址
     * @param operator 是否许可
     */
    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool)
    {
        // return _operatorApprovalMap[owner][operator];
        return operator == _marketAddress;
    }

    function supportsInterface(bytes4 interfaceID)
        external
        view
        returns (bool)
    {
        return
            interfaceID == _InterfaceId_ERC165 || // ERC-165 support
            interfaceID == _InterfaceId_ERC1155_Metadata || // metadata
            interfaceID == _InterfaceId_ERC1155; // erc1155
    }

    /**
     * @dev 铸币
     * @param value 值
     * @param uri token的描述元信息地址
     */
    function mint(
        uint256 value,
        string memory uri
    ) public returns (bool, string memory) {
        // if (_exists(id)) {
        //     return (false, "铸币失败: id已经存在!");
        // }
        uint256 id = _tokenId++;
        // 检测两个值相加
        uint256 tempBalance = _balanceMap[id][msg.sender] + value;

        require(tempBalance >= _balanceMap[id][msg.sender], "余额溢出!");

        // 增加数量
        _balanceMap[id][msg.sender] = tempBalance;

        tempBalance = _idValueMap[id] + value;
        require(tempBalance >= _idValueMap[id], "余额溢出!");
        // 增加总值
        _idValueMap[id] = tempBalance;

        // 设置token的uri
        _tokenUriMap[id] = uri;

        emit TransferSingle(msg.sender, address(0), msg.sender, id, value);
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
    //  /**
    //  * @dev 销毁
    //  * @param id 令牌Id
    //  */
    // function burn(uint256 id) public returns(bool, string memory) {

    //     if(!_exists(id)) {
    //         return (false, "销毁失败: id不存在!");
    //     }

    //  uint256 curValue = _balanceMap[id][msg.sender];

    //  if(curValue == 0) {
    //     return (false, "销毁失败: 不拥有token!");
    //   }

    //   // 增加数量
    //   _balanceMap[id][msg.sender] = 0;

    //   // 增加减去
    //   _idValueMap[id] = _idValueMap[id].sub(curValue);

    //   emit TransferSingle(msg.sender, msg.sender, address(0), id, curValue);
    //     //
    //   return (true, "");
    // }

    /**
     * @dev 判断id是否存在的
     */

    function _exists(uint256 id) internal returns (bool) {
        return _idValueMap[id] != 0;
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

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) internal {
        require(
            ERC1155TokenReceiver(to).onERC1155Received(
                operator,
                from,
                id,
                value,
                data
            ) == ERC1155_ACCEPTED
        );
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal {
        require(
            ERC1155TokenReceiver(to).onERC1155BatchReceived(
                operator,
                from,
                ids,
                values,
                data
            ) == ERC1155_BATCH_ACCEPTED
        );
    }
}
