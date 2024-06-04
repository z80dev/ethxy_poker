import pytest

card_values = [
    "A",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "T",
    "J",
    "Q",
    "K"
]

card_suits = [
    "c",
    "d",
    "h",
    "s"
]

def parse_card_value(card_val):
    val, suit = card_val
    value = card_values[val]
    suit = card_suits[suit]
    return value + suit

def card_name_to_val(card_name):
    value = card_name[0]
    suit = card_name[1]
    value = card_values.index(value)
    suit = card_suits.index(suit)
    return (suit * 13) + value

@pytest.fixture
def poker_checker(project, deployer):
    return project.PokerHandUtils.deploy(sender=deployer)

def test_poker_checker_card_name(poker_checker):
    value = poker_checker.getCardName(0)
    name = parse_card_value(value)
    assert name == "Ac"
    assert card_name_to_val(name) == 0

    value = poker_checker.getCardName(13)
    name = parse_card_value(value)
    assert name == "Ad"

    value = poker_checker.getCardName(26)
    name = parse_card_value(value)
    assert name == "Ah"

    value = poker_checker.getCardName(39)
    name = parse_card_value(value)
    assert name == "As"

    value = poker_checker.getCardName(51)
    name = parse_card_value(value)
    assert name == "Ks"

OUTCOMES = [
    "Royal Flush",
    "Straight Flush",
    "Four of a Kind",
    "Full House",
    "Flush",
    "Straight",
    "Three of a Kind",
    "Two Pair",
    "Pair",
    "High Card"
]

def test_poker_checker_card_pair(poker_checker):
    cards = ["Ac", "Ad", "2h", "4c", "8h"]
    card_vals = [card_name_to_val(card) for card in cards]
    outcome, sorted_cards = poker_checker.evaluateHand(card_vals)
    assert OUTCOMES[outcome] == "Pair"

def test_poker_checker_card_two_pair(poker_checker):
    cards = ["Ac", "Ad", "2h", "2c", "8h"]
    card_vals = [card_name_to_val(card) for card in cards]
    outcome, sorted_cards = poker_checker.evaluateHand(card_vals)
    assert OUTCOMES[outcome] == "Two Pair"

def test_poker_checker_card_three_of_a_kind(poker_checker):
    cards = ["Ac", "Ad", "Ah", "2c", "8h"]
    card_vals = [card_name_to_val(card) for card in cards]
    outcome, sorted_cards = poker_checker.evaluateHand(card_vals)
    assert OUTCOMES[outcome] == "Three of a Kind"

def test_poker_checker_card_straight(poker_checker):
    cards = ["Ac", "2d", "3h", "4c", "5h"]
    card_vals = [card_name_to_val(card) for card in cards]
    outcome, sorted_cards = poker_checker.evaluateHand(card_vals)
    assert OUTCOMES[outcome] == "Straight"

def test_poker_checker_card_flush(poker_checker):
    cards = ["Ac", "2c", "3c", "4c", "9c"]
    card_vals = [card_name_to_val(card) for card in cards]
    outcome, sorted_cards = poker_checker.evaluateHand(card_vals)
    assert OUTCOMES[outcome] == "Flush"

def test_poker_checker_card_full_house(poker_checker):
    cards = ["Ac", "Ad", "Ah", "2c", "2h"]
    card_vals = [card_name_to_val(card) for card in cards]
    outcome, sorted_cards = poker_checker.evaluateHand(card_vals)
    assert OUTCOMES[outcome] == "Full House"

def test_poker_checker_card_four_of_a_kind(poker_checker):
    cards = ["Ac", "Ad", "Ah", "As", "2h"]
    card_vals = [card_name_to_val(card) for card in cards]
    outcome, sorted_cards = poker_checker.evaluateHand(card_vals)
    assert OUTCOMES[outcome] == "Four of a Kind"

def test_poker_checker_card_straight_flush(poker_checker):
    cards = ["Ac", "2c", "3c", "4c", "5c"]
    card_vals = [card_name_to_val(card) for card in cards]
    outcome, sorted_cards = poker_checker.evaluateHand(card_vals)
    assert OUTCOMES[outcome] == "Straight Flush"

def test_poker_checker_card_royal_flush(poker_checker):
    cards = ["Ac", "Kc", "Qc", "Jc", "Tc"]
    card_vals = [card_name_to_val(card) for card in cards]
    outcome, sorted_cards = poker_checker.evaluateHand(card_vals)
    assert OUTCOMES[outcome] == "Royal Flush"

def test_poker_checker_specific_cards(poker_checker):
    player_a_cards = [37, 28]
    player_a_card_names = [parse_card_value(poker_checker.getCardName(card)) for card in player_a_cards]
    assert player_a_card_names == ["Qh", "3h"]
    player_b_cards = [50, 17]
    player_b_card_names = [parse_card_value(poker_checker.getCardName(card)) for card in player_b_cards]
    assert player_b_card_names == ["Qs", "5d"]
    flop = [5, 10, 11, 16, 22]
    flop_card_names = [parse_card_value(poker_checker.getCardName(card)) for card in flop]
    assert flop_card_names == ["6c", "Jc", "Qc", "4d", "Td"]

@pytest.fixture
def poker(poker_checker, project, treasury):
    return project.Poker.deploy(poker_checker, treasury, sender=treasury)

def parse_outcome(outcome):
    if outcome == 0:
        return "Royal Flush"
    elif outcome == 1:
        return "Straight Flush"
    elif outcome == 2:
        return "Four of a Kind"
    elif outcome == 3:
        return "Full House"
    elif outcome == 4:
        return "Flush"
    elif outcome == 5:
        return "Straight"
    elif outcome == 6:
        return "Three of a Kind"
    elif outcome == 7:
        return "Two Pair"
    elif outcome == 8:
        return "Pair"
    elif outcome == 9:
        return "High Card"

def format_card(card):
    # a card is a number between 0 and 51
    # 0-12 are spades, 13-25 are hearts, 26-38 are clubs, 39-51 are diamonds
    # we want to take a card (number) as input, and return a string like AH (ace of hearts)
    # or TS (10 of spades)
    #
    if card < 0 or card > 51:
        raise ValueError("Card number should be between 0 and 51.")

    # Determine the suit based on the card number
    suits = ['s', 'h', 'c', 'd']  # Spades, Hearts, Clubs, Diamonds
    suit = suits[card // 13]

    # Determine the rank based on the card number
    rank = (card + 1) % 13
    ranks = {1: 'A', 10: 'T', 11: 'J', 12: 'Q', 0: 'K'}
    rank_str = ranks.get(rank, str(rank))

    return rank_str + suit

MAX_TIES = 0
TIES_COUNT = {}

def print_game(poker, events, player_a_address, player_b_address):
    global MAX_TIES
    cards, outcomeA, outcomeB, gameEnd = [e for e in events if not e.event_name == 'Tie']
    ties = [e for e in events if e.event_name == 'Tie']
    print(len(ties), " ties")
    if len(ties) > MAX_TIES:
        MAX_TIES = len(ties)
    if len(ties) > 0:
        if len(ties) not in TIES_COUNT:
            TIES_COUNT[len(ties)] = 0
        TIES_COUNT[len(ties)] += 1
    if len(events) > 5:
        print("More than 5 events, something went wrong.")
        for event in events:
            print(event)

    print(len(events), " events")
    playerA = [card for card in cards['playerA']]
    playerB = [card for card in cards['playerB']]
    field = [card for card in cards['flop']]

    print("Player A: ", [format_card(card) for card in playerA])
    print("Player B: ", [format_card(card) for card in playerB])
    print("Field: ", [format_card(card) for card in field])

    a_cards = list(playerA + field)
    b_cards = list(playerB + field)

    a_outcome = outcomeA['outcome']
    b_outcome = outcomeB['outcome']

    winner = gameEnd['winner']

    print(f"Player A outcome: {parse_outcome(a_outcome)} {outcomeA['sorted_cards']}")
    print(f"Player B outcome: {parse_outcome(b_outcome)} {outcomeB['sorted_cards']}")

    if winner == player_a_address:
        print("Player A won!")
    elif winner == player_b_address:
        print("Player B won!")
    else:
        print("Tie!")


def test_poker_games(deployer, other_buyer, poker, project, treasury):
    deployer_pre_balance = deployer.balance
    poker.set_enabled(True, sender=treasury)
    poker.set_denomination_enabled(10**16, True, sender=treasury)
    poker.set_fee_rate(10**16, 40, sender=treasury)
    poker.start_game(10**16, 0, value=10 ** 16, sender=deployer)
    other_buyer_pre_balance = other_buyer.balance
    start = poker.start_game(10**16, 0, value=10 ** 16, sender=other_buyer)
    assert poker.GameStarted(0, deployer, other_buyer, 0, 0, 10 ** 16, 7) in start.events

    project.provider.mine()

    tx = poker.close_game(0, sender=treasury)

    for i in range(1, 20):
        print("Game ", i)
        FEE_AMT = 10**16 / 50
        NET_WIN = int(10**16 - (2 * FEE_AMT))
        deployer_pre_balance = deployer.balance
        poker.start_game(10**16, 0, value=10**16, sender=deployer)
        other_buyer_pre_balance = other_buyer.balance
        start = poker.start_game(10**16, 0, value=10**16, sender=other_buyer)
        deployer_pre_balance = deployer.balance
        other_buyer_pre_balance = other_buyer.balance
        project.provider.mine()
        tx = poker.close_game(i, sender=treasury)
        game_end = tx.events[-1]
        assert game_end['winner'] in [deployer, other_buyer]
        if game_end['winner'] == other_buyer:
            assert other_buyer.balance > other_buyer_pre_balance
            assert deployer.balance == deployer_pre_balance
        else:
            assert deployer.balance > deployer_pre_balance
            assert other_buyer.balance == other_buyer_pre_balance
        print(tx.events)
        print_game(poker, tx.events, deployer, other_buyer)
        print("MAX TIES: ", MAX_TIES)
        print("TIES COUNT: ", TIES_COUNT)

def test_challenge(deployer, other_buyer, poker, project, treasury):
    poker.set_enabled(True, sender=treasury)
    poker.set_denomination_enabled(10**16, True, sender=treasury)
    poker.set_fee_rate(10**16, 40, sender=treasury)
    start = poker.challenge_player(0, 1, 10**16, value=10**16, sender=deployer)
    assert poker.ChallengeCreated(deployer.address, 0, 1, 10**16) in start.events

    project.provider.mine()

    accept = poker.accept_challenge(1, 0, 10**16, value=10**16, sender=other_buyer)

    assert poker.GameStarted(0, deployer, other_buyer, 0, 1, 10**16, 8) in accept.events
