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

(Note: you are supposed to be familiar with [Data::Tubes](https://metacpan.org/pod/Data::Tubes) terminology).

This module allows you to break a potentially blocking long pipeline of
operations into two parts, shifting the second part for execution in
a Mojolicious Minion.

For example, suppose you are using both [Data::Tubes](https://metacpan.org/pod/Data::Tubes) and
[Bot::ChatBots::Telegram::WebHook](https://metacpan.org/pod/Bot::ChatBots::Telegram::WebHook) in a [Mojolicious::Lite](https://metacpan.org/pod/Mojolicious::Lite) app like
this:

    use Mojolicious::Lite;
    use Data::Tubes qw< pipeline >;

    my $pipeline = pipeline(
       \&simple_operation_1,
       \&simple_operation_2,
       \&long_running_operation,
       \&simple_operation_3,
       {tap => sink},
    );

    plugin Bot::ChatBots::Telegram => sources => [
       'Bot::ChatBots::Telegram::WebHook',
       processor => $pipeline,
       ...
    ];

    app->start;

When a new update comes, it will eventually hit `long_running_operation`
and block your frontend process. Ouch! This is what you can do instead:

    use Mojolicious::Lite;
    use Data::Tubes qw< pipeline >;

    # configure Minion before calling Bot::ChatBots::Minion
    plugin Minion => ...;

    # configure Bot::ChatBots::Minion to execute the second part of the
    # pipeline, for delayed execution of long_running_operation and following
    plugin 'Bot::ChatBots::Minion',
       dequeuer => pipeline(
          \&long_running_operation,
          \&simple_operation_3,
          {tap => sink},
       );

    # now app->chatbots->minion->enqueuer represents the delayed execution of
    # the long-running part of the original pipeline, so we set it as the
    # last step in our pipeline
    my $pipeline = pipeline(
       \&simple_operation_1,
       \&simple_operation_2,
       app->chatbots->minion->enqueuer,
       {tap => sink},
    );

    # the rest is as before
    plugin Bot::ChatBots::Telegram => sources => [
       'Bot::ChatBots::Telegram::WebHook',
       processor => $pipeline,
       ...
    ];

    app->start;

So the trick is to divide the long-running pipeline into two parts, where the
long-running step is the first one in the second half. You first provide this
second long-running half to Bot::ChatBots::Minion as its `dequeuer` (aliased
to `processor` for your convenience), obtaining an object that you can
retrieve via `app->chatbots->minion` and whose ["enqueuer"](#enqueuer) method allows
you to get a tube for enqueuing records.

# METHODS

## **dequeuer**

    my $sub_reference = $obj->dequeuer;
    $obj->dequeuer(sub { ... });

Accessor for the dequeue function. This is supposed to be a tube-compliant
sub reference that is executed inside a Minion worker.

You will probably not need to set it directly, in particular if you load
the class as a plugin in [Mojolicious](https://metacpan.org/pod/Mojolicious) or [Mojolicious::Lite](https://metacpan.org/pod/Mojolicious::Lite) because in
that case you MUST pass it as parameter `dequeuer` or `processor`.

## **enqueue**

    $obj->enqueue($record);

You should not need to call this directly, it is used by ["enqueuer"](#enqueuer) behind
the scenes.

## **enqueuer**

    my $sub_reference = $obj->enqueuer;

    # most of the times you will get it like this:
    my $sub = $app->chatbots->minion->enqueuer;

Get a tube-compliant sub reference for enqueuing records for delayed
execution inside a Minion.

## **logger**

    my $logger = $obj->logger;
    $obj->logger($new_logger);

Accessor for the logger, defaults to ["get\_logger" in Log::Any](https://metacpan.org/pod/Log::Any#get_logger).

## **minion**

    my $minion = $obj->minion;
    $obj->minion($new_minion_ref);

Accessor for the minion object.

## **name**

    my $name = $obj->name;
    $obj->name('new name');

Accessor for the name of the object, also used as topic for queuing tasks.
Defaults to the value of ["typename"](#typename).

## **register**

    $obj->register($app, $conf);

    # implicitly called when you load the class as a Mojolicious::Plugin
    plugin 'Bot::ChatBots::Minion' => %conf;

Plugin registration method, consumed by Mojolicious when loading this
class as a plugin.

## **sink**

    my $sink = $obj->sink;
    $obj->sink($boolean_value);

Accessor for a flag indicating whether ["enqueue"](#enqueue) (and consequently the
["enqueuer"](#enqueuer) when invoked) should return the input record for further
processing or not. Defaults to a _false_ value, which means that the
record is passed over for further processing; when set to a _true_ value
the enqueuer returns nothing.

## **typename**

    my $typename = $obj->typename;
    $obj->typename('new typename');

Accessor for a _typename_ string that can be useful for
logging/debugging. Defaults to the package name of which the object is
blessed (via `ref`) or to the name of the package.

# BUGS AND LIMITATIONS

Report bugs through GitHub (patches welcome).

# SEE ALSO

[Bot::ChatBots](https://metacpan.org/pod/Bot::ChatBots), [Bot::ChatBots::Telegram](https://metacpan.org/pod/Bot::ChatBots::Telegram).

# AUTHOR

Flavio Poletti <polettix@cpan.org>

# COPYRIGHT AND LICENSE

Copyright (C) 2016 by Flavio Poletti <polettix@cpan.org>

This module is free software. You can redistribute it and/or modify it
under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.
