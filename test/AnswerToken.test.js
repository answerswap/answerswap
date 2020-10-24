const { expectRevert } = require('@openzeppelin/test-helpers');
const AnswerToken = artifacts.require('AnswerToken');

contract('AnswerToken', ([alice, bob, carol]) => {
    beforeEach(async () => {
        this.Answer = await AnswerToken.new({ from: alice });
    });

    it('should have correct name and symbol and decimal', async () => {
        const name = await this.Answer.name();
        const symbol = await this.Answer.symbol();
        const decimals = await this.Answer.decimals();
        assert.equal(name.valueOf(), 'AnswerToken');
        assert.equal(symbol.valueOf(), 'Answer');
        assert.equal(decimals.valueOf(), '18');
    });

    it('should only allow owner to mint token', async () => {
        await this.Answer.mint(alice, '100', { from: alice });
        await this.Answer.mint(bob, '1000', { from: alice });
        await expectRevert(
            this.Answer.mint(carol, '1000', { from: bob }),
            'Ownable: caller is not the owner',
        );
        const totalSupply = await this.Answer.totalSupply();
        const aliceBal = await this.Answer.balanceOf(alice);
        const bobBal = await this.Answer.balanceOf(bob);
        const carolBal = await this.Answer.balanceOf(carol);
        assert.equal(totalSupply.valueOf(), '1100');
        assert.equal(aliceBal.valueOf(), '100');
        assert.equal(bobBal.valueOf(), '1000');
        assert.equal(carolBal.valueOf(), '0');
    });

    it('should supply token transfers properly', async () => {
        await this.Answer.mint(alice, '100', { from: alice });
        await this.Answer.mint(bob, '1000', { from: alice });
        await this.Answer.transfer(carol, '10', { from: alice });
        await this.Answer.transfer(carol, '100', { from: bob });
        const totalSupply = await this.Answer.totalSupply();
        const aliceBal = await this.Answer.balanceOf(alice);
        const bobBal = await this.Answer.balanceOf(bob);
        const carolBal = await this.Answer.balanceOf(carol);
        assert.equal(totalSupply.valueOf(), '1100');
        assert.equal(aliceBal.valueOf(), '90');
        assert.equal(bobBal.valueOf(), '900');
        assert.equal(carolBal.valueOf(), '110');
    });

    it('should fail if you try to do bad transfers', async () => {
        await this.Answer.mint(alice, '100', { from: alice });
        await expectRevert(
            this.Answer.transfer(carol, '110', { from: alice }),
            'ERC20: transfer amount exceeds balance',
        );
        await expectRevert(
            this.Answer.transfer(carol, '1', { from: bob }),
            'ERC20: transfer amount exceeds balance',
        );
    });
  });
