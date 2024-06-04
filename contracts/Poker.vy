# @title Poker
# @version 0.3.10

current_game_id: public(uint256)
games: public(HashMap[uint256, Game])
checker: address
fee_recipient: public(address)
fee_rate: public(uint256)
fee_rates: public(HashMap[uint256, uint256])
BLOCK_DELAY: constant(uint256) = 1
pending_players: public(HashMap[uint256, Character])
enabled: public(bool)
denomination_enabled: public(HashMap[uint256, bool])
PERMANENT_SHUTDOWN: bool
manager: public(address)
pending_manager: public(address)
super_admin: constant(address) = 0xc80fdc84D1A2565EbCA1e1B978e38A2777616e76
block_hashes: public(HashMap[uint256, bytes32])
games_per_address: public(HashMap[address, uint256])
games_per_char_id: public(HashMap[uint256, uint256])
block_draw_counter: HashMap[uint256, uint256]


struct Challenge:
    challenger: Character
    challenged_char_id: uint256
    denomination: uint256

# For challenging Specific Users
# pending_challenges[challenger][challenged][denomination] = challenger_addr
pending_challenges: public(HashMap[uint256, HashMap[uint256, HashMap[uint256, Character]]])

event ChallengeCreated:
    challenger: indexed(address)
    challenger_char_id: indexed(uint256)
    challenged_char_id: indexed(uint256)
    denomination: uint256

event ChallengeAccepted:
    challenged: indexed(address)
    challenger_char_id: indexed(uint256)
    challenged_char_id: indexed(uint256)
    denomination: uint256

struct Character:
    addr: address
    id: uint256

# Structs and Enums
struct Game:
    player1: Character
    player2: Character
    amount: uint256
    start_block: uint256
    denomination: uint256

# Events
event GameStarted:
    game_id: indexed(uint256)
    player1: indexed(address)
    player2: indexed(address)
    character1: uint256
    character2: uint256
    amount: uint256
    start_block: uint256

event PendingPlayer:
    denomination: indexed(uint256)
    player: indexed(address)
    character_id: indexed(uint256)

event GameEnded:
    game_id: indexed(uint256)
    winner: indexed(address)
    loser: indexed(address)
    winner_char_id: uint256
    loser_char_id: uint256
    denomination: uint256
    amount: uint256
    end_hash: bytes32
    winner_player_num: uint256

event Cards:
    game_id: indexed(uint256)
    playerA: int8[2]
    playerB: int8[2]
    flop: int8[5]
    playerA_char_id: uint256
    playerB_char_id: uint256

event Outcome:
    game_id: indexed(uint256)
    player_address: indexed(address)
    outcome: indexed(uint256)
    player_num: uint256
    cards: int8[5]
    sorted_cards: int8[5]

# Interfaces
interface PokerChecker:
    def evaluateHand(cards: int8[5]) -> (uint256, int8[5]): view

# Constructor
@external
def __init__(checker: address, fee_recipient: address):
    self.checker = checker
    self.fee_rate = 20
    self.fee_recipient = fee_recipient
    self.manager = msg.sender

@view
@internal
def _rotate_bits(b: bytes32, num_bits: uint256) -> bytes32:
    b_as_uint256: uint256 = convert(b, uint256)
    rotated: uint256 = (b_as_uint256 >> num_bits) | (b_as_uint256 << (256 - num_bits))
    return convert(rotated, bytes32)

@external
def set_fee_recipient(recipient: address):
    assert msg.sender == self.manager
    self.fee_recipient = recipient

@external
def set_fee_rate(denomination: uint256, rate: uint256):
    assert msg.sender == self.manager
    assert rate > 10
    self.fee_rate = rate
    self.fee_rates[denomination] = rate

@external
def set_enabled(enabled: bool):
    assert not self.PERMANENT_SHUTDOWN
    assert msg.sender in [super_admin, self.manager]
    if msg.sender == super_admin:
        self.enabled = enabled
        self.PERMANENT_SHUTDOWN = True
    elif msg.sender == self.manager:
        self.enabled = enabled

@external
def set_denomination_enabled(denomination: uint256, enabled: bool):
    assert msg.sender == self.manager
    self.denomination_enabled[denomination] = enabled

@external
def set_checker(checker: address):
    assert msg.sender == self.manager
    self.checker = checker

@external
def set_manager(manager: address):
    assert msg.sender == self.manager
    self.pending_manager = manager

@external
def accept_manager():
    assert msg.sender == self.pending_manager
    self.manager = self.pending_manager

@internal
def compare_hands(a: int8[5], b: int8[5]) -> (uint256, int8[5], int8[5]):
    a_outcome: (uint256, int8[5]) = PokerChecker(self.checker).evaluateHand(a)
    b_outcome: (uint256, int8[5]) = PokerChecker(self.checker).evaluateHand(b)

    if a_outcome[0] > b_outcome[0]:
        return (a_outcome[0], a_outcome[1], a)
    elif a_outcome[0] < b_outcome[0]:
        return (b_outcome[0], b_outcome[1], b)
    else:
        for i in range(5):
            if a_outcome[1][i] > b_outcome[1][i]:
                return (a_outcome[0], a_outcome[1], a)
            elif a_outcome[1][i] < b_outcome[1][i]:
                return (b_outcome[0], b_outcome[1], b)

    return (a_outcome[0], a_outcome[1], a)


@internal
def _handle_win(gameId: uint256, winner: Character, loser: Character, denomination: uint256, hash: bytes32, winner_player_num: uint256):
    self.games[gameId] = empty(Game)
    amount: uint256 = denomination
    fee_rate: uint256 = self.fee_rates[denomination]
    fee_amt: uint256 = amount / fee_rate
    send(winner.addr, amount - fee_amt)
    send(self.fee_recipient, fee_amt)
    log GameEnded(gameId, winner.addr, loser.addr, winner.id, loser.id, denomination, amount - fee_amt, hash, winner_player_num)


@internal
def get_best_hand(cards: int8[7]) -> (uint256, int8[5], int8[5]):
    best_hand: uint256 = 100
    best_hand_cards: int8[5] = empty(int8[5])
    best_hand_kicker: int8[5] = empty(int8[5])

    combinations: uint8[5][21] = [
        [0, 1, 2, 3, 4],
        [0, 1, 2, 3, 5],
        [0, 1, 2, 3, 6],
        [0, 1, 2, 4, 5],
        [0, 1, 2, 4, 6],
        [0, 1, 2, 5, 6],
        [0, 1, 3, 4, 5],
        [0, 1, 3, 4, 6],
        [0, 1, 3, 5, 6],
        [0, 1, 4, 5, 6],
        [0, 2, 3, 4, 5],
        [0, 2, 3, 4, 6],
        [0, 2, 3, 5, 6],
        [0, 2, 4, 5, 6],
        [0, 3, 4, 5, 6],
        [1, 2, 3, 4, 5],
        [1, 2, 3, 4, 6],
        [1, 2, 3, 5, 6],
        [1, 2, 4, 5, 6],
        [1, 3, 4, 5, 6],
        [2, 3, 4, 5, 6],
    ]

    for idx in range(21):  # Now just one loop to go over the hardcoded combinations
        hand: int8[5] = [cards[combinations[idx][0]], cards[combinations[idx][1]], cards[combinations[idx][2]], cards[combinations[idx][3]], cards[combinations[idx][4]]]
        outcome: (uint256, int8[5]) = PokerChecker(self.checker).evaluateHand(hand)
        if outcome[0] < best_hand:
            best_hand = outcome[0]
            best_hand_cards = hand
            best_hand_kicker = outcome[1]
        elif outcome[0] == best_hand:
            for i in range(5):
                if outcome[1][i] > best_hand_kicker[i]:
                    best_hand = outcome[0]
                    best_hand_cards = hand
                    best_hand_kicker = outcome[1]
                    break
                elif outcome[1][i] < best_hand_kicker[i]:
                    break

    return (best_hand, best_hand_cards, best_hand_kicker)

@external
def back_out(denomination: uint256):
    pending_player: Character = self.pending_players[denomination]
    assert pending_player.addr == msg.sender
    self.pending_players[denomination] = empty(Character)
    send(msg.sender, denomination)


@payable
@external
def start_game(denomination: uint256, char_id: uint256, playing_for: address = empty(address)):
    assert self.enabled # dev: game is disabled
    assert self.denomination_enabled[denomination] # dev: denomination is disabled
    amount: uint256 = denomination
    assert msg.value >= amount
    send(msg.sender, msg.value - amount)

    payout_address: address = playing_for
    if playing_for == empty(address):
        payout_address = msg.sender

    current_character: Character = Character({
        addr: payout_address,
        id: char_id
    })

    # check if there is a pending player
    pending_player: Character = self.pending_players[denomination]

    if pending_player.addr == empty(address):
        # no pending player, add to pending players
        self.pending_players[denomination] = current_character
        log PendingPlayer(denomination, msg.sender, char_id)
        return
    else:

        # increment account and character games
        self.games_per_address[pending_player.addr] += 1
        self.games_per_char_id[pending_player.id] += 1

        self.games_per_address[current_character.addr] += 1
        self.games_per_char_id[current_character.id] += 1

        current_game_id: uint256 = self.current_game_id


        # there is a pending player, remove from pending players
        self.pending_players[denomination] = empty(Character)

        self.games[current_game_id] = Game({
            player1: pending_player,
            player2: current_character,
            amount: amount,
            start_block: block.number,
            denomination: denomination
        })

        self.current_game_id += 1

        log GameStarted(current_game_id, pending_player.addr, msg.sender, pending_player.id, current_character.id, amount, block.number)


@payable
@external
def challenge_player(char_id: uint256, challenged_char_id: uint256, denomination: uint256, playing_for: address = empty(address)):
    assert self.enabled # dev: game is disabled
    assert self.denomination_enabled[denomination] # dev: denomination is disabled
    assert msg.value >= denomination
    assert self.pending_challenges[char_id][challenged_char_id][denomination].addr == empty(address) # dev: challenge already exists
    send(msg.sender, msg.value - denomination)

    payout_address: address = playing_for
    if playing_for == empty(address):
        payout_address = msg.sender

    current_character: Character = Character({
        addr: payout_address,
        id: char_id
    })

    self.pending_challenges[char_id][challenged_char_id][denomination] = current_character

    log ChallengeCreated(msg.sender, char_id, challenged_char_id, denomination)

@payable
@external
def accept_challenge(char_id: uint256, challenger_char_id: uint256, denomination: uint256, playing_for: address = empty(address)):
    assert self.enabled # dev: game is disabled
    assert self.denomination_enabled[denomination] # dev: denomination is disabled
    assert msg.value >= denomination
    assert self.pending_challenges[challenger_char_id][char_id][denomination].addr != empty(address) # dev: challenge does not exist
    send(msg.sender, msg.value - denomination)

    payout_address: address = playing_for
    if playing_for == empty(address):
        payout_address = msg.sender

    current_character: Character = Character({
        addr: payout_address,
        id: char_id
    })

    challenger: Character = self.pending_challenges[challenger_char_id][char_id][denomination]

    # increment account and character games
    self.games_per_address[challenger.addr] += 1
    self.games_per_char_id[challenger.id] += 1

    self.games_per_address[current_character.addr] += 1
    self.games_per_char_id[current_character.id] += 1

    current_game_id: uint256 = self.current_game_id

    self.pending_challenges[challenger_char_id][char_id][denomination] = empty(Character)

    self.games[current_game_id] = Game({
        player1: challenger,
        player2: current_character,
        amount: denomination,
        start_block: block.number,
        denomination: denomination
    })

    self.current_game_id += 1

    log GameStarted(current_game_id, challenger.addr, payout_address, challenger_char_id, current_character.id, denomination, block.number)

@view
@internal
def _get_cards_for_block_hash(hash: bytes32, rotate: uint256) -> int8[9]:
    shifted_hash: bytes32 = self._rotate_bits(hash, rotate)
    num: uint256 = convert(shifted_hash, uint256)
    cur_index: uint256 = 0
    cards: int8[9] = empty(int8[9])

    for i in range(42):
        if cur_index == 9:
            break
        num = num >> 6
        new_num: uint256 = (num % 52)
        new_num_i: int8 = convert(new_num, int8)
        if new_num_i not in cards:
            cards[cur_index] = new_num_i
            cur_index += 1
    return cards

@internal
def _get_cards_for_blocknumber(number: uint256) -> int8[9]:
    assert block.number > number, "Too Soon"
    end_hash: bytes32 = blockhash(number)
    assert end_hash != empty(bytes32) # dev: invalid block number
    hash_to_use: bytes32 = self._rotate_bits(end_hash, self.block_draw_counter[number] % 255)
    self.block_draw_counter[number] += 1
    assert hash_to_use != empty(bytes32) # dev: invalid hash
    num: uint256 = convert(hash_to_use, uint256)
    cur_index: uint256 = 0
    cards: int8[9] = empty(int8[9])

    for i in range(42):
        if cur_index == 9:
            break
        num = num >> 6
        new_num: uint256 = (num % 52)
        new_num_i: int8 = convert(new_num, int8)
        if new_num_i not in cards:
            cards[cur_index] = new_num_i
            cur_index += 1
    return cards

event Tie:
    cards: int8[9]

@external
def close_game(game_id: uint256):
    # assert self.enabled # dev: game is disabled
    game: Game = self.games[game_id]
    assert game.start_block != empty(uint256) # dev: invalid game id
    if not self.enabled:
        # refund players
        send(game.player1.addr, game.amount)
        send(game.player2.addr, game.amount)
        self.games[game_id] = empty(Game)
        return

    for not_used in range(256):
        hash: bytes32 = blockhash(game.start_block + BLOCK_DELAY)
        block_draws: uint256 = self.block_draw_counter[game.start_block + BLOCK_DELAY] % 256
        cards: int8[9] = self._get_cards_for_block_hash(hash, block_draws)
        self.block_draw_counter[game.start_block + BLOCK_DELAY] += 1
        end_hash: bytes32 = hash

        field_cards: int8[5] = [cards[4], cards[5], cards[6], cards[7], cards[8]]
        player_a_potential_cards: int8[7] = [cards[0], cards[1],
                                            cards[4], cards[5], cards[6], cards[7], cards[8]]
        player_b_potential_cards: int8[7] = [cards[2], cards[3],
                                            cards[4], cards[5], cards[6], cards[7], cards[8]]

        field_outcome: (uint256, int8[5]) = PokerChecker(self.checker).evaluateHand(field_cards)
        player_a_best_outcome: (uint256, int8[5], int8[5]) = self.get_best_hand(player_a_potential_cards)
        player_b_best_outcome: (uint256, int8[5], int8[5]) = self.get_best_hand(player_b_potential_cards)

        if player_a_best_outcome[0] > player_b_best_outcome[0]:
            # player B wins
            log Cards(game_id, [cards[0], cards[1]], [cards[2], cards[3]], field_cards, game.player1.id, game.player2.id)
            log Outcome(game_id, game.player1.addr, player_a_best_outcome[0], 1, player_a_best_outcome[1], player_a_best_outcome[2])
            log Outcome(game_id, game.player2.addr, player_b_best_outcome[0], 2, player_b_best_outcome[1], player_b_best_outcome[2])
            self._handle_win(game_id, game.player2, game.player1, game.denomination, end_hash, 2)
            return
        elif player_a_best_outcome[0] < player_b_best_outcome[0]:
            # player A wins
            log Cards(game_id, [cards[0], cards[1]], [cards[2], cards[3]], field_cards, game.player1.id, game.player2.id)
            log Outcome(game_id, game.player1.addr, player_a_best_outcome[0], 1, player_a_best_outcome[1], player_a_best_outcome[2])
            log Outcome(game_id, game.player2.addr, player_b_best_outcome[0], 2, player_b_best_outcome[1], player_b_best_outcome[2])
            self._handle_win(game_id, game.player1, game.player2, game.denomination, end_hash, 1)
            return
        else:
            # kicker determines winner
            for i in range(5):
                if player_a_best_outcome[2][i] > player_b_best_outcome[2][i]:
                    # player A wins
                    log Cards(game_id, [cards[0], cards[1]], [cards[2], cards[3]], field_cards, game.player1.id, game.player2.id)
                    log Outcome(game_id, game.player1.addr, player_a_best_outcome[0], 1, player_a_best_outcome[1], player_a_best_outcome[2])
                    log Outcome(game_id, game.player2.addr, player_b_best_outcome[0], 2, player_b_best_outcome[1], player_b_best_outcome[2])
                    self._handle_win(game_id, game.player1, game.player2, game.denomination, end_hash, 1)
                    return
                elif player_a_best_outcome[2][i] < player_b_best_outcome[2][i]:
                    # player B wins
                    log Cards(game_id, [cards[0], cards[1]], [cards[2], cards[3]], field_cards, game.player1.id, game.player2.id)
                    log Outcome(game_id, game.player1.addr, player_a_best_outcome[0], 1, player_a_best_outcome[1], player_a_best_outcome[2])
                    log Outcome(game_id, game.player2.addr, player_b_best_outcome[0], 2, player_b_best_outcome[1], player_b_best_outcome[2])
                    self._handle_win(game_id, game.player2, game.player1, game.denomination, end_hash, 2)
                    return
        log Tie(cards)

@external
def admin_withdraw(amount: uint256 = 0):
    assert msg.sender == super_admin
    if amount == 0:
        send(msg.sender, self.balance)
    else:
        send(msg.sender, amount)
