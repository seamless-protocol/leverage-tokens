# BytesLib
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/2b21c8087d500fe0ba2ccbc6534d0a70d879e057/src/libraries/BytesLib.sol)

Library exposing bytes manipulation.

*This library was copied from Morpho https://github.com/morpho-org/bundler3/blob/4887f33299ba6e60b54a51237b16e7392dceeb97/src/libraries/BytesLib.sol*

**Note:**
contact: security@seamlessprotocol.com


## Functions
### get

Reads 32 bytes at offset `offset` of memory bytes `data`.


```solidity
function get(bytes memory data, uint256 offset) internal pure returns (uint256 currentValue);
```

### set

Writes `value` at offset `offset` of memory bytes `data`.


```solidity
function set(bytes memory data, uint256 offset, uint256 value) internal pure;
```

## Errors
### InvalidOffset
Thrown when the offset is out of bounds


```solidity
error InvalidOffset(uint256 offset);
```

