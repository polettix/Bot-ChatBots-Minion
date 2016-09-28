package Bot::ChatBots::Minion;
use strict;
use Ouch;
{ our $VERSION = '0.001'; }

use Mojo::Base 'Mojolicious::Plugin';
use Log::Any ();
use Bot::ChatBots::Utils qw< pipeline resolve_module >;

has minion   => sub { ouch 500, 'no minion set' };
has name     => sub { shift->typename };
has prefix   => 'Bot::ChatBots';
has typename => sub { return ref($_[0]) || $_[0] };

sub logger { return Log::Any->get_logger };

sub register {
   my ($self, $app, $conf) = @_;
   $self->minion($app->minion);
   $self->name($conf->{name}) if exists $conf->{name};
   $self->prefix($conf->{prefix}) if exists $conf->{prefix};
   $self->typename($conf->{typename}) if exists $conf->{typename};
   $app->helper('chatbots.minion' => sub { $self });
   return $self;
} ## end sub register

sub wrapper {
   my $self = shift;
   my $args = (@_ && ref($_[0])) ? $_[0] : {@_};
   my $topic = $args->{name} // $self->name
     or ouch 500, 'no task name available for minion wrapper';

   my $prefix = $args->{prefix} // $self->prefix;
   my $ds = $args->{downstream} // $args->{processor}
     or ouch 500, 'no processor provided for minion wrapper';
   my $rds = ref $ds;
   $ds = pipeline($rds eq 'ARRAY' ? @$ds : $ds, {prefix => $prefix})
     if $rds ne 'CODE';

   state $cache = {};
   if (! exists $cache->{$topic}) {
      $cache->{$topic} = sub {
         my $record = shift;
         $self->logger->info("enqueueing for $topic");
         $self->minion->enqueue($topic, [$record]);
         return $record;
      };
      $self->minion->add_task(
         $topic,
         sub {
            $self->logger->info("dequeuing for $topic");
            return $ds->($_[0]);
         }
      );
   }
   return $cache->{$topic};
}

42;
__END__

has dequeuer  => sub { ouch 500, 'no dequeuer set' };
has logger    => sub { Log::Any->get_logger };
has sink => 0;

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
   my $processor = $conf->{dequeuer} // $conf->{processor}
     or ouch 500, 'no processor for dequeuing defined';
   $self->dequeuer($processor);
   $self->typename($conf->{typename}) if defined $conf->{typename};
   $self->name($conf->{name}) if defined $conf->{name};
   $self->sink($conf->{sink}) if exists $conf->{sink};
   $minion->add_task($self->name, sub { shift; $self->dequeuer->(@_) });
   $app->helper('chatbots.minion' => sub { $self });
   return $self;
} ## end sub register

42;
