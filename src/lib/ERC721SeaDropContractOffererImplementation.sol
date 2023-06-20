// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ERC721SeaDropContractOffererStorage
} from "./ERC721SeaDropContractOffererStorage.sol";

import {
    MintDetails,
    MintParams,
    PublicDrop
} from "./ERC721SeaDropStructs.sol";

import {
    ERC721SeaDropErrorsAndEvents
} from "./ERC721SeaDropErrorsAndEvents.sol";

import { AllowListData, CreatorPayout } from "./SeaDropStructs.sol";

import { IERC721SeaDrop } from "../interfaces/IERC721SeaDrop.sol";

import { ISeaDropToken } from "../interfaces/ISeaDropToken.sol";

import { IDelegationRegistry } from "../interfaces/IDelegationRegistry.sol";

import { ItemType } from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    ReceivedItem,
    SpentItem,
    Schema
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title  ERC721SeaDropContractOffererImplementation
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @notice A helper contract that contains the implementation logic for
 *         ERC721SeaDropContractOfferer, to help reduce contract size
 *         on the token contract itself.
 */
contract ERC721SeaDropContractOffererImplementation is
    ERC721SeaDropErrorsAndEvents
{
    using ERC721SeaDropContractOffererStorage for ERC721SeaDropContractOffererStorage.Layout;
    using ECDSA for bytes32;

    /// @notice The delegation registry.
    IDelegationRegistry public constant DELEGATION_REGISTRY =
        IDelegationRegistry(0x00000000000076A84feF008CDAbe6409d2FE638B);

    /// @notice The original address of this contract, to ensure that it can
    ///         only be called into with delegatecall.
    address internal immutable _originalImplementation = address(this);

    /// @notice Internal constants for EIP-712: Typed structured
    ///         data hashing and signing
    bytes32 internal constant _SIGNED_MINT_TYPEHASH =
        // prettier-ignore
        keccak256(
            "SignedMint("
                "address minter,"
                "address feeRecipient,"
                "MintParams mintParams,"
                "uint256 salt"
            ")"
            "MintParams("
                "uint256 startPrice,"
                "uint256 endPrice,"
                "uint256 startTime,"
                "uint256 endTime,"
                "address paymentToken,"
                "uint256 maxTotalMintableByWallet,"
                "uint256 maxTokenSupplyForStage,"
                "uint256 dropStageIndex,"
                "uint256 feeBps,"
                "bool restrictFeeRecipients"
            ")"
        );
    bytes32 internal constant _MINT_PARAMS_TYPEHASH =
        // prettier-ignore
        keccak256(
            "MintParams("
                "uint256 startPrice,"
                "uint256 endPrice,"
                "uint256 startTime,"
                "uint256 endTime,"
                "address paymentToken,"
                "uint256 maxTotalMintableByWallet,"
                "uint256 maxTokenSupplyForStage,"
                "uint256 dropStageIndex,"
                "uint256 feeBps,"
                "bool restrictFeeRecipients"
            ")"
        );
    bytes32 internal constant _EIP_712_DOMAIN_TYPEHASH =
        // prettier-ignore
        keccak256(
            "EIP712Domain("
                "string name,"
                "string version,"
                "uint256 chainId,"
                "address verifyingContract"
            ")"
        );
    bytes32 internal constant _NAME_HASH = keccak256("ERC721SeaDrop");
    bytes32 internal constant _VERSION_HASH = keccak256("2.0");

    /**
     * @notice Constant for an unlimited `maxTokenSupplyForStage`.
     *         Used in `mintPublic` where no `maxTokenSupplyForStage`
     *         is stored in the `PublicDrop` struct.
     */
    uint256 internal constant _UNLIMITED_MAX_TOKEN_SUPPLY_FOR_STAGE =
        type(uint256).max;

    /**
     * @notice Constant for a public mint's `dropStageIndex`.
     *         Used in `mintPublic` where no `dropStageIndex`
     *         is stored in the `PublicDrop` struct.
     */
    uint256 internal constant _PUBLIC_DROP_STAGE_INDEX = 0;

    /**
     * @dev Constructor for contract deployment.
     */
    constructor() {}

    /**
     * @notice The fallback function is used as a dispatcher for SeaDrop
     *         methods.
     */
    fallback(bytes calldata) external returns (bytes memory output) {
        // Ensure this contract is only called into with delegatecall.
        _onlyDelegateCalled();

        // Get the function selector.
        bytes4 selector = msg.sig;

        // Get the rest of the msg data after the selector.
        bytes calldata data = msg.data[4:];

        if (selector == IERC721SeaDrop.getPublicDrop.selector) {
            // Return the public drop.
            return
                abi.encode(
                    ERC721SeaDropContractOffererStorage.layout()._publicDrop
                );
        } else if (selector == ISeaDropToken.getAllowedSeaport.selector) {
            // Return the allowed Seaport.
            return
                abi.encode(
                    ERC721SeaDropContractOffererStorage
                        .layout()
                        ._enumeratedAllowedSeaport
                );
        } else if (selector == ISeaDropToken.getCreatorPayouts.selector) {
            // Return the creator payouts.
            return
                abi.encode(
                    ERC721SeaDropContractOffererStorage.layout()._creatorPayouts
                );
        } else if (selector == ISeaDropToken.getAllowListMerkleRoot.selector) {
            // Return the creator payouts.
            return
                abi.encode(
                    ERC721SeaDropContractOffererStorage
                        .layout()
                        ._allowListMerkleRoot
                );
        } else if (selector == ISeaDropToken.getAllowedFeeRecipients.selector) {
            // Return the allowed fee recipients.
            return
                abi.encode(
                    ERC721SeaDropContractOffererStorage
                        .layout()
                        ._enumeratedFeeRecipients
                );
        } else if (selector == ISeaDropToken.getSigners.selector) {
            // Return the allowed signers.
            return
                abi.encode(
                    ERC721SeaDropContractOffererStorage
                        .layout()
                        ._enumeratedSigners
                );
        } else if (selector == ISeaDropToken.getDigestIsUsed.selector) {
            // Get the digest.
            bytes32 digest = bytes32(data[0:32]);

            // Return if the digest is used.
            return
                abi.encode(
                    ERC721SeaDropContractOffererStorage.layout()._usedDigests[
                        digest
                    ]
                );
        } else if (selector == ISeaDropToken.getPayers.selector) {
            // Return the allowed signers.
            return
                abi.encode(
                    ERC721SeaDropContractOffererStorage
                        .layout()
                        ._enumeratedPayers
                );
        } else {
            // Revert if the function selector is not supported.
            revert UnsupportedFunctionSelector(selector);
        }
    }

    /**
     * @notice Returns the metadata for this contract offerer.
     *
     * @return name    The name of the contract offerer.
     * @return schemas The schemas supported by the contract offerer.
     */
    function getSeaportMetadata()
        external
        pure
        returns (
            string memory name,
            Schema[] memory schemas // map to Seaport Improvement Proposal IDs
        )
    {
        name = "ERC721SeaDrop";
        schemas = new Schema[](1);
        schemas[0].id = 12;

        // Encode the SIP-12 substandards.
        uint256[] memory substandards = new uint256[](3);
        substandards[0] = 0;
        substandards[1] = 1;
        substandards[2] = 2;
        schemas[0].metadata = abi.encode(substandards);
    }

    /**
     * @notice Implementation function to emit an event to notify update of
     *         the drop URI.
     *
     *         Do not use this method directly.
     *
     * @param dropURI The new drop URI.
     */
    function updateDropURI(string calldata dropURI) external {
        // Ensure this contract is only called into with delegatecall.
        _onlyDelegateCalled();

        // Emit an event with the update.
        emit DropURIUpdated(dropURI);
    }

    /**
     * @notice Implementation function to update the public drop data and
     *         emit an event.
     *
     *         Do not use this method directly.
     *
     * @param publicDrop The public drop data.
     */
    function updatePublicDrop(PublicDrop calldata publicDrop) external {
        // Ensure this contract is only called into with delegatecall.
        _onlyDelegateCalled();

        // Revert if the fee basis points is greater than 10_000.
        if (publicDrop.feeBps > 10_000) {
            revert InvalidFeeBps(publicDrop.feeBps);
        }

        // Revert if the startTime is past the endTime.
        if (publicDrop.startTime > publicDrop.endTime) {
            revert InvalidStartAndEndTime(
                publicDrop.startTime,
                publicDrop.endTime
            );
        }

        // Set the public drop data.
        ERC721SeaDropContractOffererStorage.layout()._publicDrop = publicDrop;

        // Emit an event with the update.
        emit PublicDropUpdated(publicDrop);
    }

    /**
     * @notice Implementation function to update the allow list merkle root
     *         for the nft contract and emit an event.
     *
     *         Do not use this method directly.
     *
     * @param allowListData The allow list data.
     */
    function updateAllowList(AllowListData calldata allowListData) external {
        // Ensure this contract is only called into with delegatecall.
        _onlyDelegateCalled();

        // Put the previous root on the stack to use for the event.
        bytes32 prevRoot = ERC721SeaDropContractOffererStorage
            .layout()
            ._allowListMerkleRoot;

        // Update the merkle root.
        ERC721SeaDropContractOffererStorage
            .layout()
            ._allowListMerkleRoot = allowListData.merkleRoot;

        // Emit an event with the update.
        emit AllowListUpdated(
            prevRoot,
            allowListData.merkleRoot,
            allowListData.publicKeyURIs,
            allowListData.allowListURI
        );
    }

    /**
     * @dev Implementation function to generate a mint order with the required
     *      consideration items.
     *
     *      Do not use this method directly.
     *
     * @param fulfiller              The address of the fulfiller.
     * @param minimumReceived        The minimum items that the caller must
     *                               receive. To specify a range of ERC-721
     *                               tokens, use a null address ERC-1155 with
     *                               the amount as the quantity.
     * @custom:param maximumSpent    Maximum items the caller is willing to
     *                               spend. Must meet or exceed the requirement.
     * @param context                Context of the order according to SIP-12,
     *                               containing the mint parameters.
     *
     * @return offer         An array containing the offer items.
     * @return consideration An array containing the consideration items.
     */
    function generateOrder(
        address fulfiller,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata /* maximumSpent */,
        bytes calldata context // encoded based on the schemaID
    )
        external
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Ensure this contract is only called into with delegatecall.
        _onlyDelegateCalled();

        // Only an allowed Seaport can call this function.
        if (
            !ERC721SeaDropContractOffererStorage.layout()._allowedSeaport[
                msg.sender
            ]
        ) {
            revert InvalidCallerOnlyAllowedSeaport(msg.sender);
        }

        // Derive the offer and consideration with effects.
        (offer, consideration) = _createOrder(
            fulfiller,
            minimumReceived,
            context,
            true
        );
    }

    /**
     * @dev Implementation view function to preview a mint order.
     *
     *      Do not use this method directly.
     *
     * @custom:param caller       The address of the caller (e.g. Seaport).
     * @param fulfiller           The address of the fulfiller.
     * @param minimumReceived     The minimum items that the caller must
     *                            receive.
     * @custom:param maximumSpent Maximum items the caller is willing to spend.
     *                            Must meet or exceed the requirement.
     * @param context             Context of the order according to SIP-12,
     *                            containing the mint parameters.
     *
     * @return offer         An array containing the offer items.
     * @return consideration An array containing the consideration items.
     */
    function previewOrder(
        address /* caller */,
        address fulfiller,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata /* maximumSpent */,
        bytes calldata context
    )
        external
        view
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Ensure this contract is only called into with delegatecall.
        _onlyDelegateCalled();

        // To avoid the solidity compiler complaining about calling a non-view
        // function here (_createOrder), we will cast it as a view and use it.
        // This is okay because we are not modifying any state when passing
        // withEffects=false.
        function(address, SpentItem[] calldata, bytes calldata, bool)
            internal
            view
            returns (SpentItem[] memory, ReceivedItem[] memory) fn;
        function(address, SpentItem[] calldata, bytes calldata, bool)
            internal
            returns (
                SpentItem[] memory,
                ReceivedItem[] memory
            ) fn2 = _createOrder;
        assembly {
            fn := fn2
        }

        // Derive the offer and consideration without effects.
        (offer, consideration) = fn(fulfiller, minimumReceived, context, false);
    }

    /**
     * @dev Decodes an order and returns the offer and substandard version.
     *
     * @param minimumReceived The minimum items that the caller must
     *                        receive.
     * @param context         Context of the order according to SIP-12.
     */
    function _decodeOrder(
        SpentItem[] calldata minimumReceived,
        bytes calldata context
    ) internal view returns (uint8 substandard) {
        // Declare an error buffer; first check that the minimumReceived has the
        // this address and a non-zero "amount" as the quantity for the mint.
        uint256 errorBuffer = _castAndInvert(minimumReceived.length == 1) |
            _castAndInvert(minimumReceived[0].itemType == ItemType.ERC1155) |
            _castAndInvert(minimumReceived[0].token == address(this)) |
            _castAndInvert(minimumReceived[0].identifier == 0) |
            _castAndInvert(minimumReceived[0].amount != 0);

        // Set the substandard version.
        substandard = uint8(context[1]);

        // Next, check for SIP-6 version byte.
        errorBuffer |= _castAndInvert(context[0] == bytes1(0x00)) << 1;

        // Next, check for supported substandard.
        errorBuffer |= _castAndInvert(substandard < 3) << 2;

        // Next, check for correct context length. Minimum is 42 bytes
        // (version byte, substandard byte, feeRecipient, minter)
        unchecked {
            errorBuffer |= _castAndInvert(context.length > 41) << 3;
        }

        // Handle decoding errors.
        if (errorBuffer != 0) {
            uint8 version = uint8(context[0]);

            // We'll first revert with SIP-6 errors to follow spec.
            // (`UnsupportedExtraDataVersion` and `InvalidExtraDataEncoding`)
            if (errorBuffer << 254 != 0) {
                revert UnsupportedExtraDataVersion(version);
            } else if (errorBuffer << 252 != 0) {
                revert InvalidExtraDataEncoding(version);
            } else if (errorBuffer << 253 != 0) {
                revert InvalidSubstandard(substandard);
            } else {
                // errorBuffer << 255 != 0
                revert MustSpecifyERC1155ConsiderationItemForSeaDropMint();
            }
        }
    }

    /**
     * @dev Creates an order with the required mint payment.
     *
     * @param fulfiller           The fulfiller of the order.
     * @param minimumReceived     The minimum items that the caller must
     *                            receive.
     * @param context             Context of the order according to SIP-12,
     *                            containing the mint parameters.
     * @param withEffects         Whether to apply state changes of the mint.
     *
     * @return offer         An array containing the offer items.
     * @return consideration An array containing the consideration items.
     */
    function _createOrder(
        address fulfiller,
        SpentItem[] calldata minimumReceived,
        bytes calldata context,
        bool withEffects
    )
        internal
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Derive the substandard version.
        uint8 substandard = _decodeOrder(minimumReceived, context);

        // The offer is the minimumReceived which is validated in `_decodeOrder`.
        offer = minimumReceived;

        // Quantity is the amount of the ERC-1155 min received item.
        uint256 quantity = minimumReceived[0].amount;

        // All substandards have feeRecipient and minter as first two params.
        address feeRecipient = address(bytes20(context[2:22]));
        address minter = address(bytes20(context[22:42]));

        // If the minter is the zero address, set it to the fulfiller.
        if (minter == address(0)) {
            minter = fulfiller;
        }

        // Start compiling the MintDetails struct to avoid stack too deep.
        MintDetails memory mintDetails = MintDetails({
            feeRecipient: feeRecipient,
            payer: fulfiller,
            minter: minter,
            quantity: quantity,
            withEffects: withEffects
        });

        if (substandard == 0) {
            // 0: Public mint
            consideration = _mintPublic(mintDetails);
        } else if (substandard == 1) {
            // 1: Allow list mint
            MintParams memory mintParams = abi.decode(
                context[42:362],
                (MintParams)
            );
            // Instead of putting the proof in memory, pass context and offset
            // to use it directly from calldata.
            consideration = _mintAllowList(
                mintDetails,
                mintParams,
                context,
                362
            );
        } else {
            // substandard == 2
            // 2: Signed mint
            MintParams memory mintParams = abi.decode(
                context[42:362],
                (MintParams)
            );
            uint256 salt = uint256(bytes32(context[362:394]));
            bytes32 signatureR = bytes32(context[394:426]);
            bytes32 signatureVS = bytes32(context[426:458]);
            consideration = _mintSigned(
                mintDetails,
                mintParams,
                salt,
                signatureR,
                signatureVS
            );
        }
    }

    /**
     * @notice Mint a public drop stage.
     *
     * @param mintDetails The mint details
     */
    function _mintPublic(
        MintDetails memory mintDetails
    ) internal returns (ReceivedItem[] memory consideration) {
        // Get the public drop.
        PublicDrop memory publicDrop = ERC721SeaDropContractOffererStorage
            .layout()
            ._publicDrop;

        // Check that the stage is active and calculate the current price.
        uint256 currentPrice = _currentPrice(
            publicDrop.startTime,
            publicDrop.endTime,
            publicDrop.startPrice,
            publicDrop.endPrice
        );

        // Validate the mint parameters.
        // If passed withEffects=true, emits an event for analytics.
        consideration = _validateMint(
            mintDetails,
            currentPrice,
            publicDrop.paymentToken,
            publicDrop.maxTotalMintableByWallet,
            _UNLIMITED_MAX_TOKEN_SUPPLY_FOR_STAGE,
            publicDrop.feeBps,
            _PUBLIC_DROP_STAGE_INDEX,
            publicDrop.restrictFeeRecipients
        );
    }

    /**
     * @notice Mint an allow list drop stage.
     *
     * @param mintDetails  The mint details.
     * @param mintParams   The mint parameters.
     * @param context      The context of the order.
     * @param proofOffsetInContext The offset of the proof in the context.
     */
    function _mintAllowList(
        MintDetails memory mintDetails,
        MintParams memory mintParams,
        bytes calldata context,
        uint256 proofOffsetInContext
    ) internal returns (ReceivedItem[] memory consideration) {
        // Verify the proof.
        if (
            !_verifyProof(
                context,
                proofOffsetInContext,
                ERC721SeaDropContractOffererStorage
                    .layout()
                    ._allowListMerkleRoot,
                keccak256(abi.encode(mintDetails.minter, mintParams))
            )
        ) {
            revert InvalidProof();
        }

        // Check that the stage is active and calculate the current price.
        uint256 currentPrice = _currentPrice(
            mintParams.startTime,
            mintParams.endTime,
            mintParams.startPrice,
            mintParams.endPrice
        );

        // Validate the mint parameters.
        // If passed withEffects=true, emits an event for analytics.
        consideration = _validateMint(
            mintDetails,
            currentPrice,
            mintParams.paymentToken,
            mintParams.maxTotalMintableByWallet,
            mintParams.maxTokenSupplyForStage,
            mintParams.feeBps,
            mintParams.dropStageIndex,
            mintParams.restrictFeeRecipients
        );
    }

    /**
     * @notice Mint with a server-side signature.
     *         Note that a signature can only be used once.
     *
     * @param mintDetails  The mint details.
     * @param mintParams   The mint parameters.
     * @param salt         The salt for the signed mint.
     * @param signatureR   The server-side signature `r` value.
     * @param signatureVS  The server-side signature `vs` value.
     */
    function _mintSigned(
        MintDetails memory mintDetails,
        MintParams memory mintParams,
        uint256 salt,
        bytes32 signatureR,
        bytes32 signatureVS
    ) internal returns (ReceivedItem[] memory consideration) {
        // Get the digest to verify the EIP-712 signature.
        bytes32 digest = _getDigest(
            mintDetails.minter,
            mintDetails.feeRecipient,
            mintParams,
            salt
        );

        // Ensure the digest has not already been used.
        if (ERC721SeaDropContractOffererStorage.layout()._usedDigests[digest]) {
            revert SignatureAlreadyUsed();
        } else if (mintDetails.withEffects) {
            // Mark the digest as used.
            ERC721SeaDropContractOffererStorage.layout()._usedDigests[
                digest
            ] = true;
        }

        // Check that the stage is active and calculate the current price.
        uint256 currentPrice = _currentPrice(
            mintParams.startTime,
            mintParams.endTime,
            mintParams.startPrice,
            mintParams.endPrice
        );

        // Validate the mint parameters.
        // If passed withEffects=true, emits an event for analytics.
        consideration = _validateMint(
            mintDetails,
            currentPrice,
            mintParams.paymentToken,
            mintParams.maxTotalMintableByWallet,
            mintParams.maxTokenSupplyForStage,
            mintParams.feeBps,
            mintParams.dropStageIndex,
            mintParams.restrictFeeRecipients
        );

        // Use the recover method to see what address was used to create
        // the signature on this data.
        // Note that if the digest doesn't exactly match what was signed we'll
        // get a random recovered address.
        address recoveredAddress = digest.recover(signatureR, signatureVS);
        if (
            !ERC721SeaDropContractOffererStorage.layout()._allowedSigners[
                recoveredAddress
            ]
        ) {
            revert InvalidSignature(recoveredAddress);
        }
    }

    /**
     * @dev Validates a mint, reverting if the mint is invalid.
     *      If withEffects=true, sets mint recipient and emits an event.
     *
     * @param mintDetails           The mint details.
     * @param currentPrice          The current price.
     * @param paymentToken          The payment token.
     * @param maxTotalMintableByWallet The maximum total mintable by wallet.
     * @param maxTokenSupplyForStage The maximum token supply for the stage.
     * @param feeBps                The fee basis points.
     * @param dropStageIndex        The drop stage index.
     * @param restrictFeeRecipients Whether to restrict fee recipients.
     */
    function _validateMint(
        MintDetails memory mintDetails,
        uint256 currentPrice,
        address paymentToken,
        uint256 maxTotalMintableByWallet,
        uint256 maxTokenSupplyForStage,
        uint256 feeBps,
        uint256 dropStageIndex,
        bool restrictFeeRecipients
    ) internal returns (ReceivedItem[] memory consideration) {
        // Check the payer is allowed.
        _checkPayerIsAllowed(mintDetails.payer, mintDetails.minter);

        // Check the number of mints are availabl.
        _checkMintQuantity(
            mintDetails.minter,
            mintDetails.quantity,
            maxTotalMintableByWallet,
            maxTokenSupplyForStage
        );

        // Check that the fee recipient is allowed if restricted.
        _checkFeeRecipientIsAllowed(
            mintDetails.feeRecipient,
            restrictFeeRecipients
        );

        // Set the required consideration items.
        consideration = _requiredConsideration(
            mintDetails.feeRecipient,
            feeBps,
            mintDetails.quantity,
            currentPrice,
            paymentToken
        );

        // Apply the state changes of the mint.
        if (mintDetails.withEffects) {
            // Emit an event for the mint, for analytics.
            emit SeaDropMint(mintDetails.payer, dropStageIndex);
        }
    }

    /**
     * @dev Internal view function to derive the current price of a stage
     *      based on the the starting price and ending price. If the start
     *      and end prices differ, the current price will be interpolated on
     *      a linear basis.
     *
     *      Since this function is only used for consideration items, it will
     *      round up.
     *
     * @param startTime  The starting time of the stage.
     * @param endTime    The end time of the stage.
     * @param startPrice The starting price of the stage.
     * @param endPrice   The ending price of the stage.
     *
     * @return price The current price.
     */
    function _currentPrice(
        uint256 startTime,
        uint256 endTime,
        uint256 startPrice,
        uint256 endPrice
    ) internal view returns (uint256 price) {
        // Check that the drop stage has started and not ended.
        // This ensures that the startTime is not greater than the current
        // block timestamp and endTime is greater than the current block
        // timestamp. If this condition is not upheld `duration`, `elapsed`,
        // and `remaining` variables will underflow.
        _checkActive(startTime, endTime);

        // Return the price if startPrice == endPrice.
        if (startPrice == endPrice) {
            return endPrice;
        }

        // Declare variables to derive in the subsequent unchecked scope.
        uint256 duration;
        uint256 elapsed;
        uint256 remaining;

        // Skip underflow checks as startTime <= block.timestamp < endTime.
        unchecked {
            // Derive the duration for the stage and place it on the stack.
            duration = endTime - startTime;

            // Derive time elapsed since the stage started & place on stack.
            elapsed = block.timestamp - startTime;

            // Derive time remaining until stage expires and place on stack.
            remaining = duration - elapsed;
        }

        // Aggregate new amounts weighted by time with rounding factor.
        uint256 totalBeforeDivision = ((startPrice * remaining) +
            (endPrice * elapsed));

        // Use assembly to combine operations and skip divide-by-zero check.
        assembly {
            // Multiply by iszero(iszero(totalBeforeDivision)) to ensure
            // amount is set to zero if totalBeforeDivision is zero,
            // as intermediate overflow can occur if it is zero.
            price := mul(
                iszero(iszero(totalBeforeDivision)),
                // Subtract 1 from the numerator and add 1 to the result
                // to get the proper rounding direction to round up.
                // Division is performed with no zero check as duration
                // cannot be zero as long as startTime < endTime.
                add(div(sub(totalBeforeDivision, 1), duration), 1)
            )
        }
    }

    /**
     * @notice Check that the drop stage is active.
     *
     * @param startTime The drop stage start time.
     * @param endTime   The drop stage end time.
     */
    function _checkActive(uint256 startTime, uint256 endTime) internal view {
        // Define a variable if the drop stage is inactive.
        bool inactive;

        // Using the same check for time boundary from Seaport.
        // startTime <= block.timestamp < endTime
        assembly {
            inactive := or(
                iszero(gt(endTime, timestamp())),
                gt(startTime, timestamp())
            )
        }

        // Revert if the drop stage is not active.
        if (inactive) {
            revert NotActive(block.timestamp, startTime, endTime);
        }
    }

    /**
     * @notice Check that the fee recipient is allowed.
     *
     * @param feeRecipient          The fee recipient.
     * @param restrictFeeRecipients If the fee recipients are restricted.
     */
    function _checkFeeRecipientIsAllowed(
        address feeRecipient,
        bool restrictFeeRecipients
    ) internal view {
        // Ensure the fee recipient is not the zero address.
        if (feeRecipient == address(0)) {
            revert FeeRecipientCannotBeZeroAddress();
        }

        // Revert if the fee recipient is restricted and not allowed.
        if (restrictFeeRecipients)
            if (
                !ERC721SeaDropContractOffererStorage
                    .layout()
                    ._allowedFeeRecipients[feeRecipient]
            ) {
                revert FeeRecipientNotAllowed(feeRecipient);
            }
    }

    /**
     * @notice Check that the payer is allowed when not the minter.
     *
     * @param payer The payer.
     * @param minter The minter.
     */
    function _checkPayerIsAllowed(address payer, address minter) internal view {
        if (
            // Note: not using _cast pattern here to short-circuit
            // and skip loading the allowed payers or delegation registry.
            payer != minter &&
            !ERC721SeaDropContractOffererStorage.layout()._allowedPayers[
                payer
            ] &&
            !DELEGATION_REGISTRY.checkDelegateForAll(payer, minter)
        ) {
            revert PayerNotAllowed(payer);
        }
    }

    /**
     * @notice Check that the wallet is allowed to mint the desired quantity.
     *
     * @param minter                   The mint recipient.
     * @param quantity                 The number of tokens to mint.
     * @param maxTotalMintableByWallet The max allowed mints per wallet.
     * @param maxTokenSupplyForStage   The max token supply for the drop stage.
     */
    function _checkMintQuantity(
        address minter,
        uint256 quantity,
        uint256 maxTotalMintableByWallet,
        uint256 maxTokenSupplyForStage
    ) internal view {
        // Get the mint stats from the token contract.
        (
            uint256 minterNumMinted,
            uint256 totalMinted,
            uint256 maxSupply
        ) = IERC721SeaDrop(address(this)).getMintStats(minter);

        // Ensure mint quantity doesn't exceed maxTotalMintableByWallet.
        if (quantity + minterNumMinted > maxTotalMintableByWallet) {
            revert MintQuantityExceedsMaxMintedPerWallet(
                quantity + minterNumMinted,
                maxTotalMintableByWallet
            );
        }

        // Ensure mint quantity doesn't exceed maxSupply.
        if (quantity + totalMinted > maxSupply) {
            revert MintQuantityExceedsMaxSupply(
                quantity + totalMinted,
                maxSupply
            );
        }

        // Ensure mint quantity doesn't exceed maxTokenSupplyForStage.
        if (quantity + totalMinted > maxTokenSupplyForStage) {
            revert MintQuantityExceedsMaxTokenSupplyForStage(
                quantity + totalMinted,
                maxTokenSupplyForStage
            );
        }
    }

    /**
     * @notice Derive the required consideration items for the mint,
     *         includes the fee recipient and creator payouts.
     *
     * @param feeRecipient The fee recipient.
     * @param feeBps       The fee basis points.
     * @param quantity     The number of tokens to mint.
     * @param currentPrice The current price of each token.
     * @param paymentToken The payment token.
     */
    function _requiredConsideration(
        address feeRecipient,
        uint256 feeBps,
        uint256 quantity,
        uint256 currentPrice,
        address paymentToken
    ) internal view returns (ReceivedItem[] memory receivedItems) {
        // If the mint price is zero, return early as there
        // are no required consideration items.
        if (currentPrice == 0) {
            return new ReceivedItem[](0);
        }

        // Revert if the fee basis points are greater than 10_000.
        if (feeBps > 10_000) {
            revert InvalidFeeBps(feeBps);
        }

        // Set the itemType.
        ItemType itemType = paymentToken == address(0)
            ? ItemType.NATIVE
            : ItemType.ERC20;

        // Put the total mint price on the stack.
        uint256 totalPrice = quantity * currentPrice;

        // Get the fee amount.
        // Note that the fee amount is rounded down in favor of the creator.
        uint256 feeAmount = (totalPrice * feeBps) / 10_000;

        // Get the creator payout amount.
        // Fee amount is <= totalPrice per above.
        uint256 payoutAmount;
        unchecked {
            payoutAmount = totalPrice - feeAmount;
        }

        // Put the creator payouts on the stack.
        CreatorPayout[]
            storage creatorPayouts = ERC721SeaDropContractOffererStorage
                .layout()
                ._creatorPayouts;

        // Put the length of total creator payouts on the stack.
        uint256 creatorPayoutsLength = creatorPayouts.length;

        // Revert if the creator payouts are not set.
        if (creatorPayoutsLength == 0) {
            revert CreatorPayoutsNotSet();
        }

        // Put the start index including the fee on the stack.
        uint256 startIndexWithFee = feeAmount != 0 ? 1 : 0;

        // Initialize the returned array with the correct length.
        receivedItems = new ReceivedItem[](
            startIndexWithFee + creatorPayoutsLength
        );

        // Add a consideration item for the fee recipient.
        if (feeAmount != 0) {
            receivedItems[0] = ReceivedItem({
                itemType: itemType,
                token: paymentToken,
                identifier: uint256(0),
                amount: feeAmount,
                recipient: payable(feeRecipient)
            });
        }

        // Add a consideration item for each creator payout.
        for (uint256 i = 0; i < creatorPayoutsLength; ) {
            // Put the creator payout on the stack.
            CreatorPayout memory creatorPayout = creatorPayouts[i];

            // Get the creator payout amount.
            // Note that the payout amount is rounded down.
            uint256 creatorPayoutAmount = (payoutAmount *
                creatorPayout.basisPoints) / 10_000;

            receivedItems[startIndexWithFee + i] = ReceivedItem({
                itemType: itemType,
                token: paymentToken,
                identifier: uint256(0),
                amount: creatorPayoutAmount,
                recipient: payable(creatorPayout.payoutAddress)
            });

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Internal view function to derive the EIP-712 domain separator.
     *
     * @return The derived domain separator.
     */
    function _deriveDomainSeparator() internal view returns (bytes32) {
        // prettier-ignore
        return keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @notice Implementation function to update the allowed Seaport contracts.
     *
     *         Do not use this method directly.
     *
     * @param allowedSeaport The allowed Seaport addresses.
     */
    function updateAllowedSeaport(address[] calldata allowedSeaport) external {
        // Ensure this contract is only called into with delegatecall.
        _onlyDelegateCalled();

        // Put the lengths on the stack for more efficient access.
        uint256 allowedSeaportLength = allowedSeaport.length;
        uint256 enumeratedAllowedSeaportLength = ERC721SeaDropContractOffererStorage
                .layout()
                ._enumeratedAllowedSeaport
                .length;

        // Reset the old mapping.
        for (uint256 i = 0; i < enumeratedAllowedSeaportLength; ) {
            ERC721SeaDropContractOffererStorage.layout()._allowedSeaport[
                ERC721SeaDropContractOffererStorage
                    .layout()
                    ._enumeratedAllowedSeaport[i]
            ] = false;
            unchecked {
                ++i;
            }
        }

        // Set the new mapping for allowed Seaport contracts.
        for (uint256 i = 0; i < allowedSeaportLength; ) {
            // Ensure the allowed Seaport address is not the zero address.
            if (allowedSeaport[i] == address(0)) {
                revert AllowedSeaportCannotBeZeroAddress();
            }

            ERC721SeaDropContractOffererStorage.layout()._allowedSeaport[
                allowedSeaport[i]
            ] = true;
            unchecked {
                ++i;
            }
        }

        // Set the enumeration.
        ERC721SeaDropContractOffererStorage
            .layout()
            ._enumeratedAllowedSeaport = allowedSeaport;

        // Emit an event for the update.
        emit AllowedSeaportUpdated(allowedSeaport);
    }

    /**
     * @notice Updates the creator payouts and emits an event.
     *         The basis points must add up to 10_000 exactly.
     *
     * @param creatorPayouts The creator payout address and basis points.
     */
    function updateCreatorPayouts(
        CreatorPayout[] calldata creatorPayouts
    ) external {
        // Ensure this contract is only called into with delegatecall.
        _onlyDelegateCalled();

        // Reset the creator payout array.
        delete ERC721SeaDropContractOffererStorage.layout()._creatorPayouts;

        // Track the total basis points.
        uint256 totalBasisPoints;

        // Put the total creator payouts length on the stack.
        uint256 creatorPayoutsLength = creatorPayouts.length;

        // Revert if no creator payouts were provided.
        if (creatorPayoutsLength == 0) {
            revert CreatorPayoutsNotSet();
        }

        for (uint256 i; i < creatorPayoutsLength; ) {
            // Get the creator payout.
            CreatorPayout memory creatorPayout = creatorPayouts[i];

            // Ensure the creator payout address is not the zero address.
            if (creatorPayout.payoutAddress == address(0)) {
                revert CreatorPayoutAddressCannotBeZeroAddress();
            }

            // Ensure the basis points are not zero.
            if (creatorPayout.basisPoints == 0) {
                revert CreatorPayoutBasisPointsCannotBeZero();
            }

            // Add to the total basis points.
            totalBasisPoints += creatorPayout.basisPoints;

            // Push to storage.
            ERC721SeaDropContractOffererStorage.layout()._creatorPayouts.push(
                creatorPayout
            );

            unchecked {
                ++i;
            }
        }

        // Ensure the total basis points equals 10_000 exactly.
        if (totalBasisPoints != 10_000) {
            revert InvalidCreatorPayoutTotalBasisPoints(totalBasisPoints);
        }

        // Emit an event with the update.
        emit CreatorPayoutsUpdated(creatorPayouts);
    }

    /**
     * @notice Updates the allowed fee recipient and emits an event.
     *
     * @param feeRecipient The fee recipient.
     * @param allowed      If the fee recipient is allowed.
     */
    function updateAllowedFeeRecipient(
        address feeRecipient,
        bool allowed
    ) external {
        // Ensure this contract is only called into with delegatecall.
        _onlyDelegateCalled();

        if (feeRecipient == address(0)) {
            revert FeeRecipientCannotBeZeroAddress();
        }

        // Track the enumerated storage.
        address[]
            storage enumeratedStorage = ERC721SeaDropContractOffererStorage
                .layout()
                ._enumeratedFeeRecipients;
        mapping(address => bool)
            storage feeRecipientsMap = ERC721SeaDropContractOffererStorage
                .layout()
                ._allowedFeeRecipients;

        if (allowed) {
            if (feeRecipientsMap[feeRecipient]) {
                revert DuplicateFeeRecipient();
            }
            feeRecipientsMap[feeRecipient] = true;
            enumeratedStorage.push(feeRecipient);
        } else {
            if (!feeRecipientsMap[feeRecipient]) {
                revert FeeRecipientNotPresent();
            }
            delete ERC721SeaDropContractOffererStorage
                .layout()
                ._allowedFeeRecipients[feeRecipient];
            _asAddressArray(_removeFromEnumeration)(
                feeRecipient,
                enumeratedStorage
            );
        }

        // Emit an event with the update.
        emit AllowedFeeRecipientUpdated(feeRecipient, allowed);
    }

    /**
     * @notice Updates the allowed server-side signer and emits an event.
     *
     * @param signer  The signer to update.
     * @param allowed Whether the signer is allowed.
     */
    function updateSigner(address signer, bool allowed) external {
        // Ensure this contract is only called into with delegatecall.
        _onlyDelegateCalled();

        if (signer == address(0)) {
            revert SignerCannotBeZeroAddress();
        }

        // Track the enumerated storage.
        address[]
            storage enumeratedStorage = ERC721SeaDropContractOffererStorage
                .layout()
                ._enumeratedSigners;
        mapping(address => bool)
            storage signersMap = ERC721SeaDropContractOffererStorage
                .layout()
                ._allowedSigners;

        if (allowed) {
            if (signersMap[signer]) {
                revert DuplicateSigner();
            }
            signersMap[signer] = true;
            enumeratedStorage.push(signer);
        } else {
            if (!signersMap[signer]) {
                revert SignerNotPresent();
            }
            delete ERC721SeaDropContractOffererStorage.layout()._allowedSigners[
                signer
            ];
            _asAddressArray(_removeFromEnumeration)(signer, enumeratedStorage);
        }

        // Emit an event with the update.
        emit SignerUpdated(signer, allowed);
    }

    /**
     * @notice Updates the allowed payer and emits an event.
     *
     * @param payer   The payer to add or remove.
     * @param allowed Whether to add or remove the payer.
     */
    function updatePayer(address payer, bool allowed) external {
        // Ensure this contract is only called into with delegatecall.
        _onlyDelegateCalled();

        if (payer == address(0)) {
            revert PayerCannotBeZeroAddress();
        }

        // Track the enumerated storage.
        address[]
            storage enumeratedStorage = ERC721SeaDropContractOffererStorage
                .layout()
                ._enumeratedPayers;
        mapping(address => bool)
            storage payersMap = ERC721SeaDropContractOffererStorage
                .layout()
                ._allowedPayers;

        if (allowed) {
            if (payersMap[payer]) {
                revert DuplicatePayer();
            }
            payersMap[payer] = true;
            enumeratedStorage.push(payer);
        } else {
            if (!payersMap[payer]) {
                revert PayerNotPresent();
            }
            delete ERC721SeaDropContractOffererStorage.layout()._allowedPayers[
                payer
            ];
            _asAddressArray(_removeFromEnumeration)(payer, enumeratedStorage);
        }

        // Emit an event with the update.
        emit PayerUpdated(payer, allowed);
    }

    /**
     * @notice Verify an EIP-712 signature by recreating the data structure
     *         that we signed on the client side, and then using that to recover
     *         the address that signed the signature for this data.
     *
     * @param minter       The mint recipient.
     * @param feeRecipient The fee recipient.
     * @param mintParams   The mint params.
     * @param salt         The salt for the signed mint.
     */
    function _getDigest(
        address minter,
        address feeRecipient,
        MintParams memory mintParams,
        uint256 salt
    ) internal view returns (bytes32 digest) {
        bytes32 mintParamsHashStruct = keccak256(
            abi.encode(
                _MINT_PARAMS_TYPEHASH,
                mintParams.startPrice,
                mintParams.endPrice,
                mintParams.startTime,
                mintParams.endTime,
                mintParams.paymentToken,
                mintParams.maxTotalMintableByWallet,
                mintParams.maxTokenSupplyForStage,
                mintParams.dropStageIndex,
                mintParams.feeBps,
                mintParams.restrictFeeRecipients
            )
        );
        digest = keccak256(
            bytes.concat(
                bytes2(0x1901),
                _deriveDomainSeparator(),
                keccak256(
                    abi.encode(
                        _SIGNED_MINT_TYPEHASH,
                        minter,
                        feeRecipient,
                        mintParamsHashStruct,
                        salt
                    )
                )
            )
        );
    }

    /**
     * @notice Internal utility function to remove a uint from a supplied
     *         enumeration.
     *
     * @param toRemove    The uint to remove.
     * @param enumeration The enumerated uints to parse.
     */
    function _removeFromEnumeration(
        uint256 toRemove,
        uint256[] storage enumeration
    ) internal {
        // Cache the length.
        uint256 enumerationLength = enumeration.length;
        for (uint256 i = 0; i < enumerationLength; ) {
            // Check if the enumerated element is the one we are deleting.
            if (enumeration[i] == toRemove) {
                // Swap with the last element.
                enumeration[i] = enumeration[enumerationLength - 1];
                // Delete the (now duplicated) last element.
                enumeration.pop();
                // Exit the loop.
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Internal utility function to cast uint types to address
     *         to dedupe the need for multiple implementations of
     *         `_removeFromEnumeration`.
     *
     * @param fnIn The fn with uint input.
     *
     * @return fnOut The fn with address input.
     */
    function _asAddressArray(
        function(uint256, uint256[] storage) internal fnIn
    )
        internal
        pure
        returns (function(address, address[] storage) internal fnOut)
    {
        assembly {
            fnOut := fnIn
        }
    }

    /**
     * @dev Returns whether `leaf` exists in the Merkle tree with `root`,
     *      given `proof`.
     *
     *      Original function from solady called `verifyCalldata`, modified
     *      to use an offset from the context calldata to avoid expanding
     *      memory.
     */
    function _verifyProof(
        bytes calldata context,
        uint256 proofOffsetInContext,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool isValid) {
        /// @solidity memory-safe-assembly
        assembly {
            if sub(context.length, proofOffsetInContext) {
                // Initialize `offset` to the offset of `proof` in the calldata.
                let offset := add(context.offset, proofOffsetInContext)
                let end := add(
                    offset,
                    sub(context.length, proofOffsetInContext)
                )
                // Iterate over proof elements to compute root hash.
                // prettier-ignore
                for {} 1 {} {
                    // Slot of `leaf` in scratch space.
                    // If the condition is true: 0x20, otherwise: 0x00.
                    let scratch := shl(5, gt(leaf, calldataload(offset)))
                    // Store elements to hash contiguously in scratch space.
                    // Scratch space is 64 bytes (0x00 - 0x3f) and both elements are 32 bytes.
                    mstore(scratch, leaf)
                    mstore(xor(scratch, 0x20), calldataload(offset))
                    // Reuse `leaf` to store the hash to reduce stack operations.
                    leaf := keccak256(0x00, 0x40)
                    offset := add(offset, 0x20)
                    if iszero(lt(offset, end)) {
                        break
                    }
                }
            }
            isValid := eq(leaf, root)
        }
    }

    /**
     * @dev Internal view function to revert if this implementation contract is
     *      called without delegatecall.
     */
    function _onlyDelegateCalled() internal view {
        if (address(this) == _originalImplementation) {
            revert OnlyDelegateCalled();
        }
    }

    /**
     * @dev Internal pure function to revert with a provided reason.
     *      If no reason is provided, reverts with no message.
     */
    function _revertWithReason(bytes memory data) internal pure {
        // Bubble up the revert reason.
        assembly {
            revert(add(32, data), mload(data))
        }
    }

    /**
     * @dev Internal pure function to cast a `bool` value to a `uint256` value,
     *      then invert to match Unix style where 0 signifies success.
     *
     * @param b The `bool` value to cast.
     *
     * @return u The `uint256` value.
     */
    function _castAndInvert(bool b) internal pure returns (uint256 u) {
        assembly {
            u := iszero(b)
        }
    }

    /**
     * @dev Internal pure function to cast a `bool` value to a `uint256` value.
     *
     * @param b The `bool` value to cast.
     *
     * @return u The `uint256` value.
     */
    function _cast(bool b) internal pure returns (uint256 u) {
        assembly {
            u := b
        }
    }
}
