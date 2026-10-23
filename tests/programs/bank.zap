# Error handling with Result and an error enum, plus the ? operator.
type BankError:
	Insufficient(needed f64)
	NoAccount(id i64)
	Frozen
type Account:
	id i64
	balance f64
	frozen bool
fn find(accounts Account[], id i64) Account ? BankError:
	for a in accounts:
		if a.id == id: return a
	BankError.NoAccount(id)
fn withdraw(mut accounts Account[], id i64, amount f64) f64 ? BankError:
	acc = try find(accounts, id)
	if acc.frozen: return BankError.Frozen
	if acc.balance < amount: return BankError.Insufficient(amount - acc.balance)
	i = 0
	for a in accounts:
		if a.id == id:
			accounts[i].balance = a.balance - amount
		i += 1
	acc.balance - amount
fn describe(e BankError):
	match e:
		Insufficient(n): "insufficient funds, need {n} more"
		NoAccount(id): "no account {id}"
		Frozen: "account frozen"
mut accounts = [
	Account(id = 1, balance = 100.0, frozen = false),
	Account(id = 2, balance = 50.0, frozen = true),
]
attempts = [1, 1, 2, 3]
amounts = [30.0, 100.0, 10.0, 1.0]
for i, attempt in attempts:
	match withdraw(accounts, attempt, amounts[i]):
		left: print("ok, {left} left")
		error: print("error: {error.describe()}")

test "an enum of errors goes up to the caller through ?":
	main()
	prints """
	    ok, 70 left
	    error: insufficient funds, need 30 more
	    error: account frozen
	    error: no account 3
	    """
