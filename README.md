# NAME

Bot::ChatBots::Minion - Minion-based pipeline breaker for Bot::ChatBots

# VERSION

This document describes Bot::ChatBots::Minion version {{\[ version \]}}.

# SYNOPSIS

    # We assume that you want to break a long pipeline into two parts
    # where the second has to be executed inside a Minion

    # First pipeline's program has something like this:
    use Minion;
    use Bot::ChatBots::Minion;
    my $minion = Minion->new(...);
    my $cbm = Bot::ChatBots::Minion->new(minion => $minion);

    # Now you can use $cbm->enqueuer as a final tube e.g. as the processor
    # for Bot::ChatBots::Telegram::LongPoll/WebHook
    use Bot::ChatBots::Telegram::LongPoll;
    Bot::ChatBots::Telegram::LongPoll->new(
       token => $ENV{TOKEN},
       processor => $cbm->enqueuer
    );

    # Second pipeline's program is probably similar to this:
    use Mojolicious::Lite;
    plugin Minion => (...); # same configs as the other program!!!
    plugin 'Bot::ChatBots::Minion' => (
       dequeuer => $second_pipeline_part
    );
    app->start; # start program with "appname minion worker"


    ######################################################################
    # If you just have a Mojolicious::Lite app with e.g. Telegram WebHooks
    # it's even simpler
    use Mojolicious::Lite;
    plugin Minion => (...);
    plugin 'Bot::ChatBots::Minion' => (dequeuer => $second_pipeline);
    plugin 'Bot::ChatBots::Telegram::WebHook' => (
       ...
       processor => app->chatbots->minion->enqueuer,
    );
    ...
    app->start;
    # now you will have to both start the Mojolicious::Lite app and the
    # Minion worker!

# DESCRIPTION

This module allows you to...

# FUNCTIONS

## **whatever**

# METHODS

## **whatever**

# BUGS AND LIMITATIONS

Report bugs either through RT or GitHub (patches welcome).

# SEE ALSO

Foo::Bar.

# AUTHOR

Flavio Poletti <polettix@cpan.org>

# COPYRIGHT AND LICENSE

Copyright (C) 2016 by Flavio Poletti <polettix@cpan.org>

This module is free software. You can redistribute it and/or modify it
under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.
