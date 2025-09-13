// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract StealthAddressManager {
    // Events for stealth payments
    event StealthMetaAddressSet(
        address indexed registrant,
        uint256 spendingPubKeyPrefix,
        uint256 spendingPubKey,
        uint256 viewingPubKeyPrefix, 
        uint256 viewingPubKey
    );
    
    event StealthPayment(
        uint256 indexed ephemeralPubKeyPrefix,
        uint256 indexed ephemeralPubKey,
        address indexed stealthAddress,
        bytes32 viewTag,
        uint256 amount,
        bytes metadata
    );

    // Elliptic curve parameters for secp256k1
    uint256 constant FIELD_ORDER = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
    uint256 constant GROUP_ORDER = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
    uint256 constant GX = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
    uint256 constant GY = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;

    struct StealthMetaAddress {
        uint256 spendingPubKeyPrefix;
        uint256 spendingPubKey;
        uint256 viewingPubKeyPrefix;
        uint256 viewingPubKey;
    }

    mapping(address => StealthMetaAddress) public stealthMetaAddresses;

    /**
     * @notice Register stealth meta-address for receiving stealth payments
     * @param spendingPubKeyPrefix Prefix byte for spending public key
     * @param spendingPubKey Spending public key
     * @param viewingPubKeyPrefix Prefix byte for viewing public key  
     * @param viewingPubKey Viewing public key
     */
    function registerStealthMetaAddress(
        uint256 spendingPubKeyPrefix,
        uint256 spendingPubKey,
        uint256 viewingPubKeyPrefix,
        uint256 viewingPubKey
    ) external {
        stealthMetaAddresses[msg.sender] = StealthMetaAddress({
            spendingPubKeyPrefix: spendingPubKeyPrefix,
            spendingPubKey: spendingPubKey,
            viewingPubKeyPrefix: viewingPubKeyPrefix,
            viewingPubKey: viewingPubKey
        });

        emit StealthMetaAddressSet(
            msg.sender,
            spendingPubKeyPrefix,
            spendingPubKey,
            viewingPubKeyPrefix,
            viewingPubKey
        );
    }

    /**
     * @notice Generate stealth address from recipient's meta-address and ephemeral key
     * @param recipientMetaAddress The recipient's registered meta-address
     * @param ephemeralPrivKey Random ephemeral private key
     * @return stealthAddress The generated stealth address
     * @return ephemeralPubKeyPrefix Prefix for ephemeral public key
     * @return ephemeralPubKey The ephemeral public key
     * @return viewTag First byte of shared secret for scanning optimization
     */
    function generateStealthAddress(
        address recipientMetaAddress,
        uint256 ephemeralPrivKey
    ) public view returns (
        address stealthAddress,
        uint256 ephemeralPubKeyPrefix,
        uint256 ephemeralPubKey,
        bytes1 viewTag
    ) {
        StealthMetaAddress memory meta = stealthMetaAddresses[recipientMetaAddress];
        require(meta.spendingPubKey != 0, "Meta-address not registered");

        // Generate ephemeral public key: ephemeralPubKey = ephemeralPrivKey * G
        (ephemeralPubKeyPrefix, ephemeralPubKey) = _multiplyPoint(
            GX, GY, ephemeralPrivKey
        );

        // Compute shared secret: sharedSecret = ephemeralPrivKey * viewingPubKey
        (uint256 sharedX, uint256 sharedY) = _decompressPoint(
            meta.viewingPubKeyPrefix,
            meta.viewingPubKey
        );
        (uint256 sharedSecretX,) = _multiplyPoint(sharedX, sharedY, ephemeralPrivKey);

        // Hash shared secret to get stealth private key additive
        bytes32 hashedSharedSecret = keccak256(abi.encodePacked(sharedSecretX));
        viewTag = bytes1(hashedSharedSecret);

        // Compute stealth public key: stealthPubKey = spendingPubKey + hashedSharedSecret * G
        (uint256 additiveX, uint256 additiveY) = _multiplyPoint(
            GX, GY, uint256(hashedSharedSecret)
        );
        
        (uint256 spendingX, uint256 spendingY) = _decompressPoint(
            meta.spendingPubKeyPrefix,
            meta.spendingPubKey
        );
        
        (uint256 stealthPubKeyX, uint256 stealthPubKeyY) = _addPoints(
            spendingX, spendingY, additiveX, additiveY
        );

        // Convert public key to Ethereum address
        stealthAddress = _pubKeyToAddress(stealthPubKeyX, stealthPubKeyY);
    }

    /**
     * @notice Send payment to stealth address with metadata
     * @param recipientMetaAddress Recipient's registered meta-address
     * @param ephemeralPrivKey Random ephemeral private key for this payment
     * @param metadata Encrypted metadata (ticket info, etc.)
     */
    function sendToStealthAddress(
        address recipientMetaAddress,
        uint256 ephemeralPrivKey,
        bytes calldata metadata
    ) external payable {
        (
            address stealthAddress,
            uint256 ephemeralPubKeyPrefix,
            uint256 ephemeralPubKey,
            bytes1 viewTag
        ) = generateStealthAddress(recipientMetaAddress, ephemeralPrivKey);

        // Transfer ETH to stealth address
        (bool success,) = stealthAddress.call{value: msg.value}("");
        require(success, "Transfer failed");

        emit StealthPayment(
            ephemeralPubKeyPrefix,
            ephemeralPubKey,
            stealthAddress,
            bytes32(viewTag),
            msg.value,
            metadata
        );
    }

    // Internal helper functions for elliptic curve operations
    function _multiplyPoint(
        uint256 x,
        uint256 y,
        uint256 scalar
    ) internal view returns (uint256, uint256) {
        if (scalar == 0) return (0, 0);
        if (scalar == 1) return (x, y);
        
        // Ensure scalar is in valid range
        scalar = scalar % GROUP_ORDER;
        if (scalar == 0) return (0, 0);
        
        // Double-and-add algorithm for scalar multiplication
        uint256 qx = 0;
        uint256 qy = 0;
        uint256 px = x;
        uint256 py = y;
        
        while (scalar > 0) {
            if (scalar & 1 == 1) {
                (qx, qy) = _addPoints(qx, qy, px, py);
            }
            (px, py) = _doublePoint(px, py);
            scalar = scalar >> 1;
        }
        
        return (qx, qy);
    }

    function _addPoints(
        uint256 x1,
        uint256 y1,
        uint256 x2,
        uint256 y2
    ) internal view returns (uint256, uint256) {
        if (x1 == 0 && y1 == 0) return (x2, y2);
        if (x2 == 0 && y2 == 0) return (x1, y1);
        
        if (x1 == x2) {
            if (y1 == y2) {
                return _doublePoint(x1, y1);
            } else {
                return (0, 0); // Point at infinity
            }
        }
        
        // Calculate slope: s = (y2 - y1) / (x2 - x1)
        uint256 dx = addmod(x2, FIELD_ORDER - x1, FIELD_ORDER);
        uint256 dy = addmod(y2, FIELD_ORDER - y1, FIELD_ORDER);
        uint256 s = mulmod(dy, _modInverse(dx, FIELD_ORDER), FIELD_ORDER);
        
        // Calculate new point: x3 = s² - x1 - x2, y3 = s(x1 - x3) - y1
        uint256 x3 = addmod(
            addmod(mulmod(s, s, FIELD_ORDER), FIELD_ORDER - x1, FIELD_ORDER),
            FIELD_ORDER - x2,
            FIELD_ORDER
        );
        
        uint256 y3 = addmod(
            mulmod(s, addmod(x1, FIELD_ORDER - x3, FIELD_ORDER), FIELD_ORDER),
            FIELD_ORDER - y1,
            FIELD_ORDER
        );
        
        return (x3, y3);
    }

    function _doublePoint(
        uint256 x,
        uint256 y
    ) internal view returns (uint256, uint256) {
        if (y == 0) return (0, 0);
        
        // Calculate slope: s = (3x² + a) / (2y), where a = 0 for secp256k1
        uint256 s = mulmod(
            mulmod(3, mulmod(x, x, FIELD_ORDER), FIELD_ORDER),
            _modInverse(mulmod(2, y, FIELD_ORDER), FIELD_ORDER),
            FIELD_ORDER
        );
        
        // Calculate new point: x3 = s² - 2x, y3 = s(x - x3) - y
        uint256 x3 = addmod(
            mulmod(s, s, FIELD_ORDER),
            FIELD_ORDER - mulmod(2, x, FIELD_ORDER),
            FIELD_ORDER
        );
        
        uint256 y3 = addmod(
            mulmod(s, addmod(x, FIELD_ORDER - x3, FIELD_ORDER), FIELD_ORDER),
            FIELD_ORDER - y,
            FIELD_ORDER
        );
        
        return (x3, y3);
    }

    function _modInverse(uint256 a, uint256 m) internal view returns (uint256) {
        // Using Fermat's little theorem: a^(p-1) ≡ 1 (mod p)
        // So: a^(-1) ≡ a^(p-2) (mod p)
        return _modExp(a, m - 2, m);
    }

    function _decompressPoint(
        uint256 prefix,
        uint256 x
    ) internal view returns (uint256, uint256) {
        // Compute y² = x³ + 7 (secp256k1 curve equation)
        uint256 y_squared = addmod(
            mulmod(mulmod(x, x, FIELD_ORDER), x, FIELD_ORDER),
            7,
            FIELD_ORDER
        );
        
        uint256 y = _modSqrt(y_squared, FIELD_ORDER);
        
        // Choose correct y based on prefix (02 = even, 03 = odd)
        if ((y % 2) != (prefix % 2)) {
            y = FIELD_ORDER - y;
        }
        
        return (x, y);
    }

    function _modSqrt(uint256 a, uint256 p) internal view returns (uint256) {
        // Tonelli-Shanks algorithm for modular square root
        // Simplified for secp256k1 where p ≡ 3 (mod 4)
        return _modExp(a, (p + 1) / 4, p);
    }

    function _modExp(
        uint256 base,
        uint256 exp,
        uint256 mod
    ) internal view returns (uint256) {
        // ModExp precompile expects: [base_length][exp_length][mod_length][base][exp][mod]
        // All values are 32 bytes (256 bits)
        bytes memory input = abi.encodePacked(
            uint256(32),  // base length
            uint256(32),  // exponent length  
            uint256(32),  // modulus length
            base,         // base value
            exp,          // exponent value
            mod           // modulus value
        );
        
        (bool success, bytes memory result) = address(0x05).staticcall(input);
        require(success, "ModExp failed");
        
        // Result is always 32 bytes for our use case
        require(result.length == 32, "Invalid result length");
        return abi.decode(result, (uint256));
    }

    function _pubKeyToAddress(
        uint256 x,
        uint256 y
    ) internal pure returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(x, y));
        return address(uint160(uint256(hash)));
    }
}