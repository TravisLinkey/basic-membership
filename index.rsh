"reach 0.1";
"use strict";

const ROSTERSIZE = 10;

const CommonInterface = {
  // show the address of the winner
  showOutcome: Fun([Address], Null),
};

const AliceInterface = {
  ...CommonInterface,
  getRoster: Fun([], Array(Address, ROSTERSIZE)),
  roster: Array(Address, ROSTERSIZE),
  payUser: Fun([Address], Null),
  getParams: Fun([], Object({
    deadline: UInt,
    signupFee: UInt,
  })),
};

const BobInterface = {
  ...CommonInterface,
  addToRoster: Fun([Address], Null),
  isMember: Fun([Address], Bool),
  shouldGetMembership: Fun([Address, UInt], Bool),
  wasPaidToday: Fun([Address], Bool),
};

export const main = Reach.App(
  { },
  [
    Participant("Alice", AliceInterface),
    ParticipantClass("Bob", BobInterface),
  ],
  (Alice, Bob) => {

    // Helper to display results to everyone
    const showOutcome = (who) =>
      each([Alice, Bob], () => {
        interact.showOutcome(who);
      });

    // 1. Alice publishes the ticket price and deadline
    Alice.only(() => {
      const [currentRoster] = declassify([interact.getRoster()]);
      const {signupFee, deadline} = declassify(interact.getParams());
    });
    Alice.publish(currentRoster, signupFee, deadline);
    
    // 2. Until timeout, allow Bobs to purchase tickets
    const [keepGoing, funder, totalSignedUp] = parallelReduce([ true, Alice, 0 ])
      .invariant(balance() == totalSignedUp * signupFee)
      .while(keepGoing)
      .case(Bob,
        (() => ({
          //  when: declassify(interact.shouldGetMembership(signupFee)),
           when: declassify(interact.shouldGetMembership(Bob, signupFee)),
          //  when: declassify(interact.isMember(Bob)),
        })),
        ((_) => signupFee),
        ((_) => {
          const buyer = this;
          Bob.only(() => interact.addToRoster(buyer));
          return [ true, funder, totalSignedUp+1 ];
        }))
       .timeout(deadline, () => {
         Anybody.publish();
         return [false, funder, totalSignedUp];
       });

       // 3. Transfer the balance to the last person who bought a ticket
       transfer(balance()).to(funder);
       commit();
       showOutcome(funder);
  }
);
