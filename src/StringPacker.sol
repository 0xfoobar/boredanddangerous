contract StringPacker {
	error UnpackableString();

	/**
	 * @dev Pack a 0-31 byte string into a bytes32.
	 */
	function _packString(string memory unpackedString)
		internal
		pure
		returns (bytes32 packedString)
	{
		if (bytes(unpackedString).length > 31) {
			revert UnpackableString();
		}
		assembly {
			// Read one word starting at the last byte of the length, so that the first
			// byte of the packed string will be its length (left-padded) and the following
			// 31 bytes will contain the string's body (right-padded).
			packedString := mload(add(unpackedString, 31))
		}
	}

	/**
	 * @dev Return the unpacked form of `packedString`.
	 * Ends contract execution and returns the string - should only
	 * be used in an external function with a string return type.
	 */
	function _returnUnpackedString(bytes32 packedString) internal pure {
		assembly {
			// Write the offset to the string in the second word of scratch space
			// so that the packed string's body is written to the zero slot, meaning
			// its final byte (which is outside the buffer written to) will not be
			// corrupted by existing memory or require an overwrite.
			mstore(0x20, 0x20)
			// Write the packed string to memory starting at the last byte of the
			// length buffer, writing the single-byte length to the end of the length
			// word and the 0-31 byte body at the start of the body word.
			mstore(0x5f, packedString)
			// Return offset, length, body
			return(0x20, 0x60)
		}
	}

	/**
	 * @dev Memory-safe string unpacking - updates the free memory pointer to allocate
	 * space for the string. Useful for strings which are used within the contract and
	 * not simply returned in metadata queries.
	 */
	function _unpackString(bytes32 packedString)
		internal
		pure
		returns (string memory unpackedString)
	{
		assembly {
			// Get free memory pointer
			let freeMemPtr := mload(0x40)
			// Increase free memory pointer by 64 bytes to allocate space for
			// the length and content.
			mstore(0x40, add(freeMemPtr, 0x40))
			// Update pointer to `unpackedString` so Solidity can provide it to the
			// parent function.
			unpackedString := freeMemPtr
			// Write the packed string to memory starting at the last byte of the
			// length buffer, placing the single-byte length at the end of the length
			// word and the 0-31 byte body at the start of the body word.
			mstore(add(freeMemPtr, 0x1f), packedString)
		}
	}
}