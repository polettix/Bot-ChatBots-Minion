# NAME

Bot::ChatBots::Minion - Minion-based pipeline breaker for Bot::ChatBots

# VERSION

This document describes Bot::ChatBots::Minion version {{\[ version \]}}.

# SYNOPSIS

    # Just send received records straight to a Minion worker
    use Mojolicious::Lite;
    plugin 'Bot::ChatBots::Minion' => Minion => [...];
    plugin 'Bot::ChatBots::Telegram' => sources => [
       'WebHook',
       processor => app->chatbots->minion->wrapper($processor_in_worker),
       ...
    ];
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
    plugin 'Bot::ChatBots::Minion';

    my $pipeline = pipeline(
       \&simple_operation_1,
       \&simple_operation_2,
       app->chatbots->minion->wrapper(
          downstream => pipeline(
             \&long_running_operation,
             \&simple_operation_3,
             {tap => sink},
          )
       ),
       {tap => sink},
    );

    # the rest is as before
    plugin Bot::ChatBots::Telegram => sources => [
       'Bot::ChatBots::Telegram::WebHook',
       processor => $pipeline,
       ...
    ];

    app->start;

So the trick is to divide the long-running pipeline into two separate
pipelines, one to be executed in the main process with the first two
simple operations and ending with a wrapper for the second pipeline, which
includes the long operation. The wrapping mechanism takes care to send the
received record along to the Minion worker, where the second pipeline will
be executed.

You don't actually have to call `pipeline` inside the wrapper invocation,
because it will be called for you if the parameter is an array reference:

    use Mojolicious::Lite;
    use Data::Tubes qw< pipeline >;

    # configure Minion before calling Bot::ChatBots::Minion
    plugin Minion => ...;
    plugin 'Bot::ChatBots::Minion';

    my $pipeline = pipeline(
       \&simple_operation_1,
       \&simple_operation_2,
       app->chatbots->minion->wrapper(
          downstream => [
             \&long_running_operation,
             \&simple_operation_3,
             {tap => sink},
          ],
       ),
       {tap => sink},
    );

    # the rest is as before
    plugin Bot::ChatBots::Telegram => sources => [
       'Bot::ChatBots::Telegram::WebHook',
       processor => $pipeline,
       ...
    ];

    app->start;

The only difference in this case is that if you do not pass ready-made
tubes (i.e. sub references) but expressions that can be turned into tubes,
they will be transformed using prefix `Bot::ChatBots` instead of the
default `Data::Tubes` (and the transformation will be subject to the
rules set for ["resolve\_module" in Bot::ChatBots::Utils](https://metacpan.org/pod/Bot::ChatBots::Utils#resolve_module).

# METHODS

## **dequeuer**

    my $sub_reference = $obj->dequeuer(%args); # OR
       $sub_reference = $obj->dequeuer(\%args);

Generate a dequeuer sub reference, which is suitable to be used in
a Minion worker process for receiving records and sending them to
a `downstream` pipeline.

The `%args` MUST contain a `downstream` parameter (or its
lower-precedence alias `processor`) with a tube-compliant sub reference
or anything that can be transformed into one via
["pipeline" in Bot::ChatBots::Utils](https://metacpan.org/pod/Bot::ChatBots::Utils#pipeline), which will be invoked inside the Minion
worker.

The following keys are recognised in `%args`:

- `downstream`

    mandatory parameter (unless `processor` is provided) carrying a tube or
    _tubifiable_ definition via `Bot::ChatBots::Utils/pipeline` (the latter
    case assumes that you also have [Data::Tubes](https://metacpan.org/pod/Data::Tubes) installed);

- `name`

    set an alternative name for enqueuing/dequeuing stuff via Minion, defaults
    to ["name"](#name);

- `prefix`

    set a prefix for automatic transformation of module names via
    `Bot::ChatBots::Utils/pipeline`, defaults to what set for ["prefix"](#prefix)
    (i.e. `Bot::ChatBots`);

- `processor`

    low-priority alias for `downstream`, see above.

This method just returns the sub reference, so you will want it if you
want to manage the Minion worker by yourself (e.g. explicitly calling
["process\_commands" in Minion::Worker](https://metacpan.org/pod/Minion::Worker#process_commands)). If you just want to install a task,
you might want to consider the convenience function ["install\_dequeuer"](#install_dequeuer)
described below.

## **enqueue**

    $obj->enqueue($record); # OR
    $obj->enqueue($record, $name);

Send a `$record` to the Minion, optionally specifing the `$name` of the
task (which defaults to ["name"](#name)). It's actually just a convenience
wrapper around ["enqueuer"](#enqueuer).

## **enqueuer**

    my $sub_reference = $obj->enqueuer();         # OR
       $sub_reference = $obj->enqueuer($name);

Generate an enqueuer tube, most probably to be used as the last tube in a
pipeline.

You can optionally pass a `$name` that will be used for enqueuing tasks
towards the Minion; by default it takes the value from ["name"](#name).

It is not mandatory that ["minion"](#minion) is defined at the time this method is
called, but it MUST be defined when the `$sub_reference` is called.

## **helper\_name**

    my $helper_name = $self->helper_name;

Default helper name. This is used by ["register"](#register) in case `$conf` does not
contain a `helper_name` itself.

## **install\_dequeuer**

    $obj->install_dequeuer(%args); # OR
    $obj->install_dequeuer(\%args);

Generate a dequeuer subroutine via ["dequeuer"](#dequeuer) and set it as a task in
Minion (via ["add\_task" in Minion](https://metacpan.org/pod/Minion#add_task)). If you are defining a custom Minion
worker process that relies on [Mojolicious::Lite](https://metacpan.org/pod/Mojolicious::Lite), you can e.g. do this:

    use Mojolicious::Lite;
    plugin 'Bot::ChatBots::Minion' ...;
    app->chatbots->minion->install_dequeuer(downstream => sub { ... });
    app->start;

## **minion**

    my $minion = $obj->minion;
    $obj->minion($new_minion_ref);

Accessor for the minion object. If you pass an array reference, it will be
used for instantiating a new [Minion](https://metacpan.org/pod/Minion) object passing its contents as the
list provided to the Minion's `new` method.

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
class as a plugin. The Mojolicious composite helper `chatbots.minion` is
set to a subroutine reference that returns an instance of the
`Bot::ChatBots::Minion` object, for possible further manipulation.

The argument `$conf` is a hash reference, the following keys are
supported:

- `minion`

    set ["minion"](#minion). Do not confuse this with `Minion` below!

- `Minion`

    load the [Minion](https://metacpan.org/pod/Minion) plugin in the `$app` and use it for setting ["minion"](#minion).
    This option points to an array reference that contains the configuration for
    instantiating the Minion plugin

- `name`

    set ["name"](#name)

- `prefix`

    set ["prefix"](#prefix)

- `typename`

    set ["typename"](#typename)

## **wrapper**

    my $sub_reference = $obj->wrapper(%args); # OR
       $sub_reference = $obj->wrapper(\%args);

Wrap a tube (or a sequence that can be transformed into a tube) in
a delayed execution via Minion. It returns a sub reference that is a valid
tube where records can be sent to a Minion worker.

The `%args` MUST contain a `downstream` parameter (or its
lower-precedence alias `processor`) with a tube-compliant sub reference
or anything that can be transformed into one via
["pipeline" in Bot::ChatBots::Utils](https://metacpan.org/pod/Bot::ChatBots::Utils#pipeline), which will be invoked inside the Minion
worker.

The following keys are recognised in `%args`:

- `downstream`

    mandatory parameter (unless `processor` is provided) carrying a tube or
    _tubifiable_ definition via `Bot::ChatBots::Utils/pipeline` (the latter
    case assumes that you also have [Data::Tubes](https://metacpan.org/pod/Data::Tubes) installed);

- `name`

    set an alternative name for enqueuing/dequeuing stuff via Minion, defaults
    to ["name"](#name)

- `prefix`

    set a prefix for automatic transformation of module names via
    `Bot::ChatBots::Utils/pipeline`, defaults to what set for ["prefix"](#prefix)
    (i.e. `Bot::ChatBots`);

- `processor`

    low-priority alias for `downstream`, see above.

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
