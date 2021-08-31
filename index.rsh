"reach 0.1";
"use strict";

const ROSTERSIZE = 10;

const CommonInterface = {
  // show the membership roster
  showOutcome: Fun([Address], Null),
};

const AliceInterface = {
  ...CommonInterface,
  roster: Array(Address, ROSTERSIZE),
  getParams: Fun([], Object({
    deadline: UInt,
    signupFee: UInt,
  })),
  getTokenParams: Fun([], Object({
    name: Bytes(32), symbol: Bytes(8),
    url: Bytes(96), metadata: Bytes(32),
    supply: UInt,
  })),
  showToken: Fun(true, Null),
};

const BobInterface = {
  ...CommonInterface,
  addToRoster: Fun([Address], Null),
  returnAmount: Fun([], UInt),
  shouldGetMembership: Fun([UInt], Bool),
};

export const main = Reach.App(
  { },
  [
    Participant("Alice", AliceInterface),
    ParticipantClass("Bob", BobInterface),
  ],
  (Alice, Bob) => {

    // Helper to display results to everyone
    const showOutcome = () =>
      each([Alice, Bob], () => {
        const me = this;
        interact.showOutcome(me);
      });

    // 0. Mint new token
    Alice.only(() => {
      const { name, symbol, url, metadata, supply } = declassify(interact.getTokenParams());
    });
    Alice.publish(name, symbol, url, metadata, supply);

    const md1 = {name, symbol, url, metadata, supply};
    const tok1 = new Token(md1);
    Alice.interact.showToken(tok1, md1);
    commit();
    
    // 1. Alice publishes the signup fee and deadline
    Alice.only(() => {
      const {signupFee, deadline} = declassify(interact.getParams());
    });
    Alice.publish(signupFee, deadline);

    // 2. Until timeout, allow Bobs to purchase membership
    const [keepGoing, funder, totalSignedUp] = parallelReduce([ true, Alice, 0 ])
      .invariant(balance() == totalSignedUp * signupFee && !tok1.destroyed())
      .while(keepGoing && totalSignedUp < ROSTERSIZE)
      .case(Bob,
        (() => ({
           when: balance(tok1) > 0 && declassify(interact.shouldGetMembership(signupFee)),
        })),
        ((_) => signupFee),
        ((_) => {
          const buyer = this;

          // check: no more tokens
          require(balance(tok1) > 0);
          Bob.only(() => {
            interact.addToRoster(buyer);
          });
          transfer(1, tok1).to(buyer);
          return [ true, funder, totalSignedUp+1 ];
        }))
       .timeout(deadline, () => {
         Anybody.publish();
         return [ false, funder, totalSignedUp ];
       });

      // 3. Transfer the balance to the funder of the contract
      showOutcome();
      transfer(balance()).to(funder);
       
      //  4. Loop to return Bob's tokens
      var [] = [];
      invariant(balance() == 0 && !tok1.destroyed());
      while (balance(tok1) !=  tok1.supply()) {
        commit();
        Bob.only(() => {
          const userTokens = declassify(interact.returnAmount());
        })
        Bob.publish(userTokens).pay([[userTokens, tok1]]);
        continue;
      }
        
      tok1.burn();
      require(tok1.destroyed() == false);
      tok1.destroy();
      commit();
  }

);
