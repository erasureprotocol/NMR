var Numeraire = artifacts.require("./Numeraire.sol");

contract('Numeraire', function(accounts) {
  it("should assert true", function(done) {
    var numeraire = Numeraire.deployed().then(function(instance) {
      console.log(instance);
    });
    assert.isTrue(true);
    done();
  });
});
