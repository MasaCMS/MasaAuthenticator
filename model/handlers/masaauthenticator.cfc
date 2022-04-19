component extends="mura.cfobject" output="false" {

    variables.modulename = "Masa Authenticator";

    function init() {
        var thispath = RemoveChars(GetDirectoryFromPath(GetCurrentTemplatePath()), 1, Len(application.configBean.get('webroot')));
        var modulepath = application.configBean.get('context') & Left(thispath, Len(thispath)-Len('/model/handlers/'));
        set('modulepath', modulepath);
        return this;
    }

    function onAdminMFAChallengeRender(m) {
        var executor = new mura.executor();
        arguments.m.event('isadminlogin', true);
        return executor.execute(filepath='#get('modulepath')#/inc/challenge.cfm', m=arguments.m);
    }

    function onSiteMFAChallengeRender(m) {
        var executor = new mura.executor();
        arguments.m.event('isadminlogin', false);
        return executor.execute(filepath='#get('modulepath')#/inc/challenge.cfm', m=arguments.m);
    }

    function onUserEdit(m) {
        if (arguments.m.globalConfig('mfa') && (arguments.m.currentUser().isSuperUser() || arguments.m.currentUser().isInGroup('Admin'))) {
            var executor = new mura.executor();
            return executor.execute(filepath='#get('modulepath')#/inc/on-user-edit.cfm', m=arguments.m);
        }
    }

    function onMFAAttemptChallenge(m) {
        var authcode = Val(arguments.m.event('authcode'));
        var gAuth = new mura.googleAuth();
        var user = arguments.m.getBean('user').loadBy(userid=session.mfa.userid);
        var isCodeValid = gAuth.authorize(user.get('masaauthkey'), authcode);

        if ( !user.get('isnew') ) {
            if ( isCodeValid ) {
                user
                    .set('masaauthdeviceverified', true)
                    .set('masaauthdatelastverified', Now())
                    .save();
            } else {
                // if invalid, check if it's a valid backup code
                isCodeValid = this.authorizeViaBackupCode(user, authcode);
            }
        }

        return isCodeValid;
    }

    function authorizeViaBackupCode(required user, required authcode) {
        var scratchCodes = user.get('masaauthscratchcodes');
        var isCodeValid = ListFind(scratchCodes, arguments.authcode);

        if ( isCodeValid ) {
            var scratchCodes = ListDeleteAt(scratchCodes, isCodeValid);
            user
                .set('masaauthscratchcodes', scratchCodes)
                .save();
        }

        return isCodeValid;
    }

    function onAdminHTMLHeadRender(m) {
        return this.getHeadQueue(arguments.m);
    }

    function onAdminHTMLFootRender(m) {
        return this.getFootQueue(arguments.m);
    }

    function getHeadQueue(m) {
        return '<link href="#get('modulepath')#/assets/masaauthenticator.css" rel="stylesheet" type="text/css" />';
    }

    function getFootQueue(m) {
        return '<script src="#get('modulepath')#/assets/masaauthenticator.js" type="text/javascript"></script>';
    }

    // function renderHTMLQueues(m) {
    //     arguments.m.addToHTMLHeadQueue(this.getHeadQueue(arguments.m));
    //     arguments.m.addToHTMLFootQueue(this.getHeadQueue(arguments.m));
    // }

}
