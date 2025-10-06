// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// --- Interfaces ---

interface IVotingEscrow {
    function balanceOf(address _owner) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

/**
 * @title GaugeController
 * @author Curve Finance, with modifications by Ande Labs
 * @notice A contract to manage liquidity gauges and direct the flow of token emissions.
 * @dev This contract allows ve-token holders to vote on which liquidity gauges
 *      receive token rewards. It calculates the relative weight of each gauge.
 */
contract GaugeController is ReentrancyGuard {
    // --- Structs ---

    struct Point {
        int256 bias;
        int256 slope;
        uint256 ts;
    }

    struct Slope {
        uint256 slope;
        uint256 power;
        uint256 end;
    }

    // --- Constants ---

    uint256 public constant WEEK = 7 days;

    // --- State Variables ---

    address public immutable token; // ANDE token
    IVotingEscrow public immutable voting_escrow;

    int256 public n_gauge_types;
    mapping(int256 => string) public gauge_type_names;

    int256 public n_gauges;
    mapping(address => int256) public gauge_types;
    mapping(int256 => address) public gauges;

    // --- Voting Data ---

    // User vote data
    mapping(address => Slope) public vote_user_slopes; // user -> slope
    mapping(address => uint256) public vote_user_power; // user -> total voting power used
    mapping(address => mapping(address => uint256)) public user_vote_weight; // user -> gauge -> weight (0-10000)
    mapping(address => uint256) public user_total_weight; // user -> total weight used

    // Last vote timestamp for a user in a gauge
    mapping(address => mapping(address => uint256)) public last_user_vote; // user -> gauge -> timestamp

    // Points for gauge weight
    mapping(address => mapping(uint256 => Point)) public points_weight; // gauge -> time -> Point
    mapping(address => uint256) public changes_weight; // gauge -> time

    // Points for type weight
    mapping(int256 => mapping(uint256 => Point)) public points_type_weight; // type -> time -> Point
    mapping(int256 => uint256) public changes_type_weight; // type -> time

    // Sum of weights per type
    mapping(int256 => uint256) public points_sum; // type -> time -> sum of weights
    mapping(int256 => uint256) public changes_sum; // type -> time

    // --- Events ---

    event AddGauge(address indexed addr, int256 gauge_type, uint256 weight);
    event NewGaugeWeight(address indexed gauge, uint256 time, uint256 weight, uint256 total_weight);
    event VoteForGauge(address indexed user, address indexed gauge, uint256 weight);

    // --- Constructor ---

    constructor(address _token, address _voting_escrow) {
        token = _token;
        voting_escrow = IVotingEscrow(_voting_escrow);
    }

    // --- External Functions ---

    /**
     * @notice Add a new gauge type.
     * @param _name Name of the gauge type.
     */
    function add_gauge_type(string memory _name) external {
        // TODO: Add access control (only admin)
        int256 type_id = n_gauge_types;
        gauge_type_names[type_id] = _name;
        n_gauge_types = type_id + 1;
    }

    /**
     * @notice Add a new gauge to the controller.
     * @param _addr Address of the gauge contract.
     * @param _gauge_type The type of the gauge.
     * @param _weight The initial weight of the gauge (for gauges with a fixed weight).
     */
    function add_gauge(address _addr, int256 _gauge_type, uint256 _weight) external {
        // TODO: Add access control (only admin)
        require(gauge_types[_addr] == 0, "GC: Gauge already registered");
        require(_gauge_type >= 0 && _gauge_type < n_gauge_types, "GC: Invalid gauge type");

        int256 n = n_gauges;

        gauges[n] = _addr;
        gauge_types[_addr] = _gauge_type + 1; // Store type as type + 1 to avoid ambiguity with 0
        n_gauges = n + 1;

        // Checkpoint logic for initial weight can be added later

        emit AddGauge(_addr, _gauge_type, _weight);
    }

    /**
     * @notice Allocate voting power to a gauge.
     * @param _gauge_addr Address of the gauge to vote for.
     * @param _user_weight Weight to assign to the gauge (0-10000, where 10000 = 100%).
     */
    function vote(address _gauge_addr, uint256 _user_weight) external nonReentrant {
        require(gauge_types[_gauge_addr] > 0, "GC: Gauge not registered");
        require(_user_weight <= 10000, "GC: Weight must be <= 10000");

        address user = msg.sender;
        uint256 user_power = voting_escrow.balanceOf(user);
        require(user_power > 0, "GC: You have no voting power");

        uint256 old_weight = user_vote_weight[user][_gauge_addr];
        uint256 new_total_weight = user_total_weight[user] - old_weight + _user_weight;
        require(new_total_weight <= 10000, "GC: Total weight exceeds 10000");

        user_total_weight[user] = new_total_weight;
        user_vote_weight[user][_gauge_addr] = _user_weight;

        // --- Checkpointing ---
        int256 gauge_type = gauge_types[_gauge_addr] - 1;
        Slope memory old_slope_data = vote_user_slopes[user];

        uint256 new_slope = user_power * _user_weight / 10000;
        vote_user_slopes[user] = Slope({slope: new_slope, power: user_power, end: block.timestamp}); // `end` is not strictly needed here, using ts

        int256 d_slope = int256(new_slope) - int256(old_slope_data.slope);

        if (d_slope != 0) {
            // Update gauge weight checkpoint
            uint256 gauge_time = (block.timestamp / WEEK) * WEEK;
            Point storage gauge_point = points_weight[_gauge_addr][gauge_time];
            gauge_point.slope += d_slope;

            // Update type weight checkpoint
            uint256 type_time = (block.timestamp / WEEK) * WEEK;
            Point storage type_point = points_type_weight[gauge_type][type_time];
            type_point.slope += d_slope;
        }

        emit VoteForGauge(user, _gauge_addr, _user_weight);
    }

    // --- View Functions ---

    function _get_weight(address _gauge_addr, uint256 _time) internal view returns (uint256) {
        uint256 time = changes_weight[_gauge_addr];
        if (time > 0) {
            Point memory point = points_weight[_gauge_addr][time];
            return uint256(int256(point.bias) - int256(point.slope) * int256(_time));
        }
        return 0;
    }

    function gauge_relative_weight(address _gauge_addr) external view returns (uint256) {
        return gauge_relative_weight_at(_gauge_addr, block.timestamp);
    }

    /**
     * @notice Get the relative weight of a gauge at a specific time.
     * @param _gauge_addr Address of the gauge.
     * @param _time The timestamp to query at.
     * @return The relative weight (scaled).
     */
    function gauge_relative_weight_at(address _gauge_addr, uint256 _time) public view returns (uint256) {
        require(_time <= block.timestamp, "GC: Time in future");

        int256 gauge_type = gauge_types[_gauge_addr] - 1;
        if (gauge_type < 0) {
            return 0;
        }

        uint256 gauge_weight = _get_gauge_weight(_gauge_addr, _time);
        uint256 type_weight = _get_type_total_weight(gauge_type, _time);

        if (type_weight == 0) {
            return 0;
        }
        return (gauge_weight * 1e18) / type_weight;
    }

    // --- Internal View Functions ---

    function _get_gauge_weight(address _gauge_addr, uint256 _time) internal view returns (uint256) {
        uint256 time = (_time / WEEK) * WEEK;
        Point memory point = points_weight[_gauge_addr][time];
        return uint256(point.slope);
    }

    function _get_type_total_weight(int256 _gauge_type, uint256 _time) internal view returns (uint256) {
        uint256 time = (_time / WEEK) * WEEK;
        Point memory point = points_type_weight[_gauge_type][time];
        return uint256(point.slope);
    }

    // --- Internal Functions ---

    /**
     * @notice Checkpoint a gauge to update its total weight.
     * @param _gauge_addr Address of the gauge.
     */
    function _checkpoint_gauge(address _gauge_addr) internal {
        // Implementation to be added
    }
}
