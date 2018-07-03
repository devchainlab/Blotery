pragma solidity ^0.4.10;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./BloteryToken.sol";

contract Blotery is Ownable {

    using SafeMath for uint256;

    struct Room {
        address owner;
        address[] players;
        uint duration;
        uint rate;
        uint prize;
        uint start;
    }

    struct Prize {
        uint winnerPrize;
        uint invitedUsersPrize;
        uint developersPrize;
        uint tokenHoldersPrize;
    }

    struct Player {
        uint balance;
        uint gamesCount;
        uint createdRoomsCount;
        address whoInvited;
    }

    mapping(bytes32 => Room) public rooms;
    mapping(address => Player) public players;
    BloteryToken public token;

    event CreateRoom(bytes32 indexed _roomID, address indexed _owner);
    event JoinTheRoom(bytes32 indexed _roomID, address indexed _who);
    event CloseRoom(bytes32 indexed _roomID);

    function Blotery(address _tokenAddress) public {
        token = BloteryToken(_tokenAddress);
    }

    function createRoom(address _owner, uint _duration, uint _rate) onlyOwner public returns(bytes32) {
        _duration *= 1 hours;
        require(_duration == 1 hours || _duration == 3 hours || _duration == 12 hours ||
            _duration == 1 days);
        require(_rate == 1 || _rate == 5 || _rate == 10 || _rate == 50 ||
            _rate == 100 || _rate == 1000 || _rate == 10000);
        subBalance(_owner, _rate);
        bytes32 roomID = keccak256(_owner, players[_owner].createdRoomsCount);
        rooms[roomID].owner = _owner;
        rooms[roomID].players.push(_owner);
        rooms[roomID].duration = _duration;
        rooms[roomID].rate = _rate;
        rooms[roomID].prize = _rate;
        rooms[roomID].start = now;
        players[_owner].createdRoomsCount++;
        CreateRoom(roomID, _owner);
        return roomID;
    }

    function joinTheRoom(address _player, bytes32 _roomID) onlyOwner public returns(bool) {
        require(now < rooms[_roomID].start + rooms[_roomID].duration);
        for (uint i = 0; i < rooms[_roomID].players.length; i++) {
            require(rooms[_roomID].players[i] != _player);
        }
        subBalance(_player, rooms[_roomID].rate);
        rooms[_roomID].players.push(_player);
        rooms[_roomID].prize += rooms[_roomID].rate;
        JoinTheRoom(_roomID, _player);
        return true;
    }

    function closeRoom(bytes32 _roomID) onlyOwner public returns(address) {
        require(now > rooms[_roomID].start + rooms[_roomID].duration);
        address winner = rooms[_roomID].players[random(rooms[_roomID].players.length)];
        uint invitedUsersCount = 0;
        for (uint i = 0; i < rooms[_roomID].players.length; i++) {
            if (players[rooms[_roomID].players[i]].whoInvited != 0x0) {
                invitedUsersCount++;
            }
        }
        uint prizePercent = rooms[_roomID].prize / 100;
        Prize memory prize;
        prize.developersPrize = prizePercent * 4;
        if (invitedUsersCount > 0) {
            prize.invitedUsersPrize = prizePercent / invitedUsersCount;
        } else {
            prize.developersPrize += prizePercent;
        }
        if (token.getTokenHoldersCount() != 0) {
            prize.tokenHoldersPrize = prizePercent * 5 / token.getTokenHoldersCount();
            for (i = 0; i < token.getTokenHoldersCount(); i++) {
                addBalance(token.getTokenHolderAddress(i), prize.tokenHoldersPrize);
            }
        } else {
            prize.developersPrize += prizePercent * 5;
        }
        prize.winnerPrize = prizePercent * 90;
        addBalance(winner, prize.winnerPrize);
        for (i = 0; i < rooms[_roomID].players.length; i++) {
            players[rooms[_roomID].players[i]].gamesCount++;
            if (players[rooms[_roomID].players[i]].whoInvited != 0x0) {
                addBalance(players[rooms[_roomID].players[i]].whoInvited, prize.invitedUsersPrize);
            }
        }
        addBalance(owner, prize.developersPrize);
        CloseRoom(_roomID);
        return winner;
    }

    function getRoomPlayers(bytes32 _roomID) public constant returns(address[]) {
        return rooms[_roomID].players;
    }

    function setInvitedUser(address _whoWasInvited, address _whoInvited) onlyOwner public returns(bool) {
        players[_whoWasInvited].whoInvited = _whoInvited;
        return true;
    }

    function addBalance(address _to, uint _amount) onlyOwner public returns(bool) {
        players[_to].balance = players[_to].balance.add(_amount);
        return true;
    }

    function subBalance(address _from, uint _amount) onlyOwner public returns(bool) {
        players[_from].balance = players[_from].balance.sub(_amount);
        return true;
    }

    function random(uint playersCount) private returns(uint) {
        uint randomNumber = uint(block.blockhash(block.number - 1)) % playersCount;
        return randomNumber;
    }

}
