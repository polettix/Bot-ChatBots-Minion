package Bot::ChatBots::Minion;
use strict;
use Ouch;
{ our $VERSION = '0.001'; }

use Mojo::Base 'Mojolicious::Plugin';
use Log::Any ();

has dequeuer  => sub { ouch 500, 'no dequeuer set' };
has logger    => sub { Log::Any->get_logger };
has minion    => sub { ouch 500, 'no minion set' };
has name      => sub { shift->typename };
has sink => 0;
has typename => sub { return ref($_[0]) || $_[0] };

sub enqueue {
   my ($self, $record) = @_;
   $self->minion->enqueue($self->name, [$record]);
   return if $self->sink;
   return $record;
} ## end sub enqueue

sub enqueuer {
   my $self = shift;
   return sub { $self->enqueue(@_) };
}

sub register {
   my ($self, $app, $conf) = @_;
   my $minion = $app->minion
     or ouch 500, 'plugin Minion MUST be loaded for Bot::ChatBots::Minion';
   $self->minion($minion);    # not really needed actually...
   my $processor = $conf->{processor}
     or ouch 500, 'no processor for dequeuing defined';
   $self->dequeuer($processor);
   $minion->add_task($self->name, sub { $self->dequeuer->(@_) });
   $app->helper('chatbots.minion' => $self);
   return $self;
} ## end sub register

42;
