describe('regression', () => {
    describe('Actions on tap', () => {
        beforeEach(async function() {
            await this.browser.execute(() => {
                window.divkitLogs = [];
            });
            await this.browser.yaOpenRegressionJson('button_actions');
        });

        it('Tap on top button', async function() {
            await this.browser.$('span=With double and long taps').then(elem => elem.click());
            const logs = await this.browser.execute(() => window.divkitLogs);

            logs.length.should.equal(1);

            await this.browser.assertView('menu', '#root');
        });

        it('Double tap on top button', async function() {
            await this.browser.$('span=With double and long taps').then(elem => elem.doubleClick());
            const logs = await this.browser.execute(() => window.divkitLogs);

            logs.length.should.equal(3);
            logs.some(it => it.action.log_id === 'doubletap_actions').should.equal(true);

            await this.browser.assertView('menu', '#root');
        });

        hermione.only.in('chromeMobile', 'pointerType="touch" is not supported on firefox');
        it('Long click on top button', async function() {
            await this.browser.yaLongTap('span=With double and long taps', 500);
            const logs = await this.browser.execute(() => window.divkitLogs);

            logs.length.should.equal(3);
            logs.some(it => it.action.log_id === 'longtap_actions').should.equal(true);

            await this.browser.assertView('menu', '#root');
        });

        it ('Tap on middle button', async function() {
            await this.browser.$('span=Without double tap').then(elem => elem.click());
            const logs = await this.browser.execute(() => window.divkitLogs);

            logs.length.should.equal(1);

            await this.browser.assertView('menu', '#root');
        });

        it('Double tap on middle button', async function() {
            await this.browser.$('span=Without double tap').then(elem => elem.doubleClick());
            const logs = await this.browser.execute(() => window.divkitLogs);

            logs.length.should.equal(2);

            await this.browser.assertView('menu', '#root');
        });

        hermione.only.in('chromeMobile', 'pointerType="touch" is not supported on firefox');
        it('Long click on middle button', async function() {
            await this.browser.yaLongTap('span=Without double tap', 500);
            const logs = await this.browser.execute(() => window.divkitLogs);

            logs.length.should.equal(2);
            logs.some(it => it.action.log_id === 'longtap_actions').should.equal(true);

            await this.browser.assertView('menu', '#root');
        });
    });
});