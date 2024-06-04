import pytest

@pytest.fixture
def deployer(accounts):
    return accounts[0]

@pytest.fixture
def treasury(accounts):
    return accounts[9]

@pytest.fixture
def other_buyer(accounts):
    return accounts[2]

@pytest.fixture
def sexy_token(project, deployer):
    token = project.Token.deploy("SEXY", "SEXY", 1 * 10 ** 18, sender=deployer)
    return token

@pytest.fixture
def xy_token(project, deployer):
    token = project.Token.deploy("XY", "XY", 1 * 10 ** 18, sender=deployer)
    return token

@pytest.fixture
def buyer(accounts):
    return accounts[1]

@pytest.fixture(autouse=True)
def setup_balances(accounts, project):
    for x in range(10):
        project.provider.set_balance(accounts[x].address, 10000000000000 * 10 ** 18)
