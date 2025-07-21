// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";
import {WrapperMyToken} from "./WrapperMyToken.sol";
import "hardhat/console.sol";

/**
 * @title 接收源链发来的NFT并发送到目标链的合约
 * @author elvis
 * @notice 该合约允许用户接收源链发来的NFT，并在目标链上铸造新的NFT。
 */
contract NFTPoolBurnAndMint is CCIPReceiver, OwnerIsCreator {
    using SafeERC20 for IERC20;

    // Custom errors to provide more descriptive revert messages.
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance.
    error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
    error FailedToWithdrawEth(address owner, address target, uint256 value); // Used when the withdrawal of Ether fails.
    error InvalidReceiverAddress(); // Used when the receiver address is 0.

    // Event emitted when a message is sent to another chain.
    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        bytes text, // The text being sent.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the CCIP message.
    );

    /**
     * @notice Emitted when a new NFT is minted.
     * @param tokenId The ID of the NFT that was minted.
     * @param newOwner The address of the new owner of the minted NFT.
     */
    event TokenMint(
        uint256 indexed tokenId, // The ID of the NFT that was minted.
        address indexed newOwner // The address of the new owner of the minted NFT.
    );

    bytes32 private s_lastReceivedMessageId; // Store the last received messageId.
    string private s_lastReceivedText; // Store the last received text.
    address public myOwner;

    IERC20 private s_linkToken;
    WrapperMyToken public wnft;
    address public sourceSender; // 源链的发送合约地址
    uint64 public sourceChainSelector; // 源链的 Chain Selector
    struct ReceivedData {
        uint256 tokenId; // NFT的ID。
        address newOwner; // NFT的新所有者地址。
    }

    /// @notice Constructor initializes the contract with the router address.
    /// @param _router The address of the router contract.
    /// @param _link The address of the link contract.
    constructor(
        address _router,
        address _link,
        address _nft,
        uint64 _sourceChainSelector
    ) CCIPReceiver(_router) {
        myOwner = msg.sender;
        s_linkToken = IERC20(_link);
        wnft = WrapperMyToken(_nft);
        sourceChainSelector = _sourceChainSelector;
    }

    /// @dev Modifier that checks the receiver address is not 0.
    /// @param _receiver The receiver address.
    modifier validateReceiver(address _receiver) {
        if (_receiver == address(0)) revert InvalidReceiverAddress();
        _;
    }

    /**
     * 销毁NFT并发送到源链，使源链解锁对应的NFT
     * @param _tokenId The ID of the NFT to burn.
     * @param newOwner The address of the new owner of the NFT.
     * @param chainSelector The chain selector for the destination chain.
     * @param receiver The address of the receiver on the destination chain.
     */
    function burnAndSendNFT(
        uint256 _tokenId,
        address newOwner,
        uint64 chainSelector,
        address receiver
    ) public returns (bytes32) {
        wnft.burn(_tokenId); // 销毁NFT
        // 发送跨链数据到源链，解锁源链的NFT
        bytes memory payload = abi.encode(_tokenId, newOwner);
        bytes32 messageId = sendMessagePayLINK(
            chainSelector,
            receiver,
            payload
        );
        return messageId;
    }

    /**
     * @notice Sends data to receiver on the destination chain.
     * @notice Pay for fees in LINK.
     * @dev Assumes your contract has sufficient LINK.
     * @param _destinationChainSelector The identifier (aka selector) for the destination blockchain.
     * @param _receiver The address of the recipient on the destination blockchain.
     * @param _text The text to be sent.
     * @return messageId The ID of the CCIP message that was sent.
     */
    function sendMessagePayLINK(
        uint64 _destinationChainSelector,
        address _receiver,
        bytes memory _text
    )
        internal
        validateReceiver(_receiver)
        returns (bytes32 messageId)
    {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            _text,
            address(s_linkToken)
        );

        // 初始化一个router客户端实例，用于与跨链路由器交互
        IRouterClient router = IRouterClient(this.getRouter());

        // 计算发送CCIP消息所需的费用
        uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

        if (fees > s_linkToken.balanceOf(address(this)))
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);

        // 批准router合约使用LINK代币支付费用
        s_linkToken.approve(address(router), fees);

        // 发送CCIP消息，并存储返回的CCIP消息ID
        messageId = router.ccipSend(_destinationChainSelector, evm2AnyMessage);

        // Emit an event with message details
        emit MessageSent(
            messageId,
            _destinationChainSelector,
            _receiver,
            _text,
            address(s_linkToken),
            fees
        );

        // Return the CCIP message ID
        return messageId;
    }

    /// @notice Sends data to receiver on the destination chain.
    /// @notice Pay for fees in native gas.
    /// @dev Assumes your contract has sufficient native gas tokens.
    /// @param _destinationChainSelector The identifier (aka selector) for the destination blockchain.
    /// @param _receiver The address of the recipient on the destination blockchain.
    /// @param _text The text to be sent.
    /// @return messageId The ID of the CCIP message that was sent.
    function sendMessagePayNative(
        uint64 _destinationChainSelector,
        address _receiver,
        bytes memory _text
    )
        external
        validateReceiver(_receiver)
        returns (bytes32 messageId)
    {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            _text,
            address(0)
        );

        // Initialize a router client instance to interact with cross-chain router
        IRouterClient router = IRouterClient(this.getRouter());

        // Get the fee required to send the CCIP message
        uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

        if (fees > address(this).balance)
            revert NotEnoughBalance(address(this).balance, fees);

        // Send the CCIP message through the router and store the returned CCIP message ID
        messageId = router.ccipSend{value: fees}(
            _destinationChainSelector,
            evm2AnyMessage
        );

        // Emit an event with message details
        emit MessageSent(
            messageId,
            _destinationChainSelector,
            _receiver,
            _text,
            address(0),
            fees
        );

        // Return the CCIP message ID
        return messageId;
    }

    /**
    设置下源链发送者地址
    */
    function setSourceSender(address _sourceSender) public onlyOwner_ {
        sourceSender = _sourceSender;
    }

    /**
     * 处理接收到的跨链数据，
     * 这里接收源链发送过来的NFT的ID和新所有者地址，并在目标链上铸造新的NFT。
     * @param any2EvmMessage 接收到的跨链消息，包含了源链发送的NFT的ID和新所有者地址。
     */
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        // Step 1：确认来自指定源链

        console.log("The received source chain Selector", any2EvmMessage.sourceChainSelector);
        console.log("The init Chain Selector", sourceChainSelector);
        require(any2EvmMessage.sourceChainSelector == sourceChainSelector, "Invalid source chain");

        // Step 2：确认是源链合约发的
        address decodedSender = abi.decode(any2EvmMessage.sender, (address));
        console.log("The received source chain address", decodedSender);
        console.log("The init Chain address", sourceSender);
        require(abi.decode(any2EvmMessage.sender, (address)) == sourceSender, "Invalid sender");
        // 获取NFTPoolLockAndRelease发送过来的NFT的ID和新所有者地址
        ReceivedData memory receivedData = abi.decode(
            any2EvmMessage.data,
            (ReceivedData)
        );
        uint256 tokenId = receivedData.tokenId; // 获取NFT的ID
        console.log("The receiverd token id is ", tokenId);
        address newOwner = receivedData.newOwner; // 获取新所有者地址
        console.log("The received newOwner address is ", newOwner);
        wnft.mintTokenWithSpecificTokenId(newOwner, tokenId); // 在目标链上铸造新的NFT
        emit TokenMint(tokenId, newOwner);
    }

    /// @notice Construct a CCIP message.
    /// @dev This function will create an EVM2AnyMessage struct with all the necessary information for sending a text.
    /// @param _receiver The address of the receiver.
    /// @param _text The string data to be sent.
    /// @param _feeTokenAddress The address of the token used for fees. Set address(0) for native gas.
    /// @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
    function _buildCCIPMessage(
        address _receiver,
        bytes memory _text,
        address _feeTokenAddress
    ) private pure returns (Client.EVM2AnyMessage memory) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(_receiver), // ABI-encoded receiver address
                data: _text, // ABI-encoded string
                tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array as no tokens are transferred
                extraArgs: Client._argsToBytes(
                    // Additional arguments, setting gas limit and allowing out-of-order execution.
                    // Best Practice: For simplicity, the values are hardcoded. It is advisable to use a more dynamic approach
                    // where you set the extra arguments off-chain. This allows adaptation depending on the lanes, messages,
                    // and ensures compatibility with future CCIP upgrades. Read more about it here: https://docs.chain.link/ccip/concepts/best-practices/evm#using-extraargs
                    Client.GenericExtraArgsV2({
                        gasLimit: 200_000, // Gas limit for the callback on the destination chain
                        allowOutOfOrderExecution: true // Allows the message to be executed out of order relative to other messages from the same sender
                    })
                ),
                // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
                feeToken: _feeTokenAddress
            });
    }

    /// @notice Fetches the details of the last received message.
    /// @return messageId The ID of the last received message.
    /// @return text The last received text.
    function getLastReceivedMessageDetails()
        external
        view
        returns (bytes32 messageId, string memory text)
    {
        return (s_lastReceivedMessageId, s_lastReceivedText);
    }

    /// @notice Fallback function to allow the contract to receive Ether.
    /// @dev This function has no function body, making it a default function for receiving Ether.
    /// It is automatically called when Ether is sent to the contract without any data.
    receive() external payable {}

    /// @notice Allows the contract owner to withdraw the entire balance of Ether from the contract.
    /// @dev This function reverts if there are no funds to withdraw or if the transfer fails.
    /// It should only be callable by the owner of the contract.
    /// @param _beneficiary The address to which the Ether should be sent.
    function withdraw(address _beneficiary) public {
        // Retrieve the balance of this contract
        uint256 amount = address(this).balance;

        // Revert if there is nothing to withdraw
        if (amount == 0) revert NothingToWithdraw();

        // Attempt to send the funds, capturing the success status and discarding any return data
        (bool sent, ) = _beneficiary.call{value: amount}("");

        // Revert if the send failed, with information about the attempted transfer
        if (!sent) revert FailedToWithdrawEth(msg.sender, _beneficiary, amount);
    }

    /// @notice Allows the owner of the contract to withdraw all tokens of a specific ERC20 token.
    /// @dev This function reverts with a 'NothingToWithdraw' error if there are no tokens to withdraw.
    /// @param _beneficiary The address to which the tokens will be sent.
    /// @param _token The contract address of the ERC20 token to be withdrawn.
    function withdrawToken(
        address _beneficiary,
        address _token
    ) public {
        // Retrieve the balance of this contract
        uint256 amount = IERC20(_token).balanceOf(address(this));

        // Revert if there is nothing to withdraw
        if (amount == 0) revert NothingToWithdraw();

        IERC20(_token).safeTransfer(_beneficiary, amount);
    }

    modifier onlyOwner_() {
        require(msg.sender == myOwner, "Not the owner");
        _;
    }
}
