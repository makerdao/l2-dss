// SPDX-License-Identifier: AGPL-3.0-or-later

/// jug.sol -- Dai Lending Rate

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.12;

interface VatLike {
    function ilks(bytes32) external returns (
        uint256 Art,   // [wad]
        uint256 rate   // [ray]
    );
    function fold(bytes32,address,int256) external;
}

contract Jug {
    // --- Data ---
    mapping (address => uint256) public wards;

    struct Ilk {
        uint256 duty;  // Collateral-specific, per-second stability fee contribution [ray]
        uint256  rho;  // Time of last drip [unix epoch time]
    }

    mapping (bytes32 => Ilk) public ilks;
    bytes32                         a;     // Don't change the storage layout for now
    address                  public vow;   // Debt Engine
    uint256                  public base;  // Global, per-second stability fee contribution [ray]

    VatLike public immutable vat;   // CDP Engine
    uint256 constant RAY = 10 ** 27;

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Init(bytes32 indexed ilk);
    event File(bytes32 indexed ilk, bytes32 indexed what, uint256 data);
    event File(bytes32 indexed what, uint256 data);
    event File(bytes32 indexed what, address data);
    event Drip(bytes32 indexed ilk);

    modifier auth {
        require(wards[msg.sender] == 1, "Jug/not-authorized");
        _;
    }

    // --- Init ---
    constructor(address vat_) {
        wards[msg.sender] = 1;
        vat = VatLike(vat_);
        emit Rely(msg.sender);
    }

    // --- Math ---
    function _rpow(uint256 x, uint256 n, uint256 b) internal pure returns (uint256 z) {
      assembly {
        switch x case 0 {switch n case 0 {z := b} default {z := 0}}
        default {
          switch mod(n, 2) case 0 { z := b } default { z := x }
          let half := div(b, 2)  // for rounding.
          for { n := div(n, 2) } n { n := div(n,2) } {
            let xx := mul(x, x)
            if iszero(eq(div(xx, x), x)) { revert(0,0) }
            let xxRound := add(xx, half)
            if lt(xxRound, xx) { revert(0,0) }
            x := div(xxRound, b)
            if mod(n,2) {
              let zx := mul(z, x)
              if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
              let zxRound := add(zx, half)
              if lt(zxRound, zx) { revert(0,0) }
              z := div(zxRound, b)
            }
          }
        }
      }
    }

    // --- Administration ---
    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    function init(bytes32 ilk) external auth {
        Ilk storage i = ilks[ilk];
        require(i.duty == 0, "Jug/ilk-already-init");
        i.duty = RAY;
        i.rho  = block.timestamp;
        emit Init(ilk);
    }

    function file(bytes32 ilk, bytes32 what, uint256 data) external auth {
        require(block.timestamp == ilks[ilk].rho, "Jug/rho-not-updated");
        if (what == "duty") ilks[ilk].duty = data;
        else revert("Jug/file-unrecognized-param");
        emit File(ilk, what, data);
    }

    function file(bytes32 what, uint256 data) external auth {
        if (what == "base") base = data;
        else revert("Jug/file-unrecognized-param");
        emit File(what, data);
    }

    function file(bytes32 what, address data) external auth {
        if (what == "vow") vow = data;
        else revert("Jug/file-unrecognized-param");
        emit File(what, data);
    }

    // --- Stability Fee Collection ---
    function drip(bytes32 ilk) external returns (uint256 rate) {
        (, uint256 prev) = vat.ilks(ilk);
        rate = _rpow(base + ilks[ilk].duty, block.timestamp - ilks[ilk].rho, RAY) * prev / RAY;
        vat.fold(ilk, vow, int256(rate) - int256(prev));
        ilks[ilk].rho = block.timestamp;
        emit Drip(ilk);
    }
}
