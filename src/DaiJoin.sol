// SPDX-License-Identifier: AGPL-3.0-or-later

/// DaiJoin.sol -- Dai adapter

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
// Copyright (C) 2022 Dai Foundation
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

interface GemLike {
    function transfer(address,uint) external returns (bool);
    function transferFrom(address,address,uint) external returns (bool);
}

interface VatLike {
    function move(address,address,uint) external;
}

contract DaiJoin {
    // --- Data ---
    mapping (address => uint) public wards;

    bytes32        a;    // Don't change the storage layout for now
    bytes32        b;    // Don't change the storage layout for now
    uint256 public live; // Active Flag

    VatLike public immutable vat;      // CDP Engine
    GemLike public immutable dai;  // Stablecoin Token
    uint256 constant RAY = 10 ** 27;

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Cage();
    event Join(address indexed usr, uint256 wad);
    event Exit(address indexed usr, uint256 wad);

    modifier auth {
        require(wards[msg.sender] == 1, "DaiJoin/not-authorized");
        _;
    }

    constructor(address vat_, address dai_) {
        wards[msg.sender] = 1;
        live = 1;
        vat = VatLike(vat_);
        dai = GemLike(dai_);
        emit Rely(msg.sender);
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

    function cage() external auth {
        live = 0;
        emit Cage();
    }

    // --- User's functions ---
    function join(address usr, uint256 wad) external {
        vat.move(address(this), usr, RAY * wad);
        dai.transferFrom(msg.sender, address(this), wad);
        emit Join(usr, wad);
    }

    function exit(address usr, uint256 wad) external {
        require(live == 1, "DaiJoin/not-live");
        vat.move(msg.sender, address(this), RAY * wad);
        dai.transfer(usr, wad);
        emit Exit(usr, wad);
    }
}