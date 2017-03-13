F.toSignIn = ->
    if F.signing
        console.log 'sigining before'
        return
    F.signing = true

    $view = $ FT.SignIn()
    winOptions = {
        title: "登录", content: $view, maximizable: false, closable: false
        layout: {outerWidth: 300, outerHeight: 260}
    }
    win = F.openModalDialog winOptions

    $tip = $view.find('.tip').html ' '
    $username = $view.find('.username')
    $password = $view.find('.password')

    signing = false
    doSignIn = ->
        $tip.html ' '
        username = $.trim $username.val()
        unless username
            $username.focus()
            return

        password = $.trim $password.val()
        unless password
            $password.focus()
            return

        signing = true
        $tip.html '登录中...'
        q = F.api.post 'api/sign-in', {username, password}
        q.then (r)->
            F.signing = false
            win.close()
            console.log(r)
            F.ping(true).then(F.gotUser)
        q.catch (xhr)->
            $tip.html F.parseXhrErrorMessage(xhr)
            signing = false

    $view.find('.sign-in-btn').click doSignIn

    $username.keydown (e)->
        doSignIn() if e.keyCode == 13

    $password.keydown (e)->
        doSignIn() if e.keyCode == 13

    win.on 'AfterClosed', -> F.signing = false

