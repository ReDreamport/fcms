class EventEmitter
    on: (name, handler)->
        unless @hanlders
            @hanlders = {}
        unless @hanlders[name]
            @hanlders[name] = []

        @hanlders[name].push handler

    off: (name, handler)->
        return unless @hanlders
        return @hanlders[name]

        F.removeFromArray @hanlders[name], handler

    fire: (name, event)->
        return unless @hanlders
        return unless @hanlders[name]

        handlers = @hanlders[name]

        event.event = name if event
        h(event) for h in handlers

FS.EventEmitter = EventEmitter
